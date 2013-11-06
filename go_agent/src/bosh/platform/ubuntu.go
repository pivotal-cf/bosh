package platform

import (
	"bosh/errors"
	"bosh/settings"
	"bosh/system"
	"bytes"
	sigar "github.com/cloudfoundry/gosigar"
	"os"
	"path/filepath"
	"text/template"
)

type ubuntu struct {
	fs        system.FileSystem
	cmdRunner system.CmdRunner
}

func newUbuntuPlatform(fs system.FileSystem, cmdRunner system.CmdRunner) (p ubuntu) {
	p.fs = fs
	p.cmdRunner = cmdRunner
	return
}

func (p ubuntu) SetupSsh(publicKey, username string) (err error) {
	homeDir, err := p.fs.HomeDir(username)
	if err != nil {
		return errors.WrapError(err, "Error finding home dir for user")
	}

	sshPath := filepath.Join(homeDir, ".ssh")
	p.fs.MkdirAll(sshPath, os.FileMode(0700))
	p.fs.Chown(sshPath, username)

	authKeysPath := filepath.Join(sshPath, "authorized_keys")
	_, err = p.fs.WriteToFile(authKeysPath, publicKey)
	if err != nil {
		return errors.WrapError(err, "Error creating authorized_keys file")
	}

	p.fs.Chown(authKeysPath, username)
	p.fs.Chmod(authKeysPath, os.FileMode(0600))

	return
}

func (p ubuntu) SetupDhcp(networks settings.Networks) (err error) {
	dnsServers := []string{}
	dnsNetwork, found := networks.DefaultNetworkFor("dns")
	if found {
		for i := len(dnsNetwork.Dns) - 1; i >= 0; i-- {
			dnsServers = append(dnsServers, dnsNetwork.Dns[i])
		}
	}

	type dhcpConfigArg struct {
		DnsServers []string
	}

	buffer := bytes.NewBuffer([]byte{})
	t := template.Must(template.New("dhcp-config").Parse(DHCP_CONFIG_TEMPLATE))

	err = t.Execute(buffer, dhcpConfigArg{dnsServers})
	if err != nil {
		return
	}

	written, err := p.fs.WriteToFile("/etc/dhcp3/dhclient.conf", buffer.String())
	if err != nil {
		return
	}

	if written {
		// Ignore errors here, just run the commands
		p.cmdRunner.RunCommand("pkill", "dhclient3")
		p.cmdRunner.RunCommand("/etc/init.d/networking", "restart")
	}

	return
}

// DHCP Config file - /etc/dhcp3/dhclient.conf
const DHCP_CONFIG_TEMPLATE = `# Generated by bosh-agent

option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

send host-name "<hostname>";

request subnet-mask, broadcast-address, time-offset, routers,
	domain-name, domain-name-servers, domain-search, host-name,
	netbios-name-servers, netbios-scope, interface-mtu,
	rfc3442-classless-static-routes, ntp-servers;

{{ range .DnsServers }}prepend domain-name-servers {{ . }};
{{ end }}`

func (p ubuntu) GetCpuLoad() (load CpuLoad, err error) {
	l := sigar.LoadAverage{}
	err = l.Get()
	if err != nil {
		return
	}

	load.One = l.One
	load.Five = l.Five
	load.Fifteen = l.Fifteen

	return
}

func (p ubuntu) GetCpuStats() (stats CpuStats, err error) {
	cpu := sigar.Cpu{}
	err = cpu.Get()
	if err != nil {
		return
	}

	stats.User = cpu.User
	stats.Sys = cpu.Sys
	stats.Wait = cpu.Wait
	stats.Total = cpu.Total()

	return
}

func (p ubuntu) GetMemStats() (stats MemStats, err error) {
	mem := sigar.Mem{}
	err = mem.Get()
	if err != nil {
		return
	}

	stats.Total = mem.Total
	stats.Used = mem.Used

	return
}

func (p ubuntu) GetSwapStats() (stats MemStats, err error) {
	swap := sigar.Swap{}
	err = swap.Get()
	if err != nil {
		return
	}

	stats.Total = swap.Total
	stats.Used = swap.Used

	return
}

func (p ubuntu) GetDiskStats(mountedPath string) (stats DiskStats, err error) {
	fsUsage := sigar.FileSystemUsage{}
	err = fsUsage.Get(mountedPath)
	if err != nil {
		return
	}

	stats.Total = fsUsage.Total
	stats.Used = fsUsage.Used
	stats.InodeTotal = fsUsage.Files
	stats.InodeUsed = fsUsage.Files - fsUsage.FreeFiles

	return
}
