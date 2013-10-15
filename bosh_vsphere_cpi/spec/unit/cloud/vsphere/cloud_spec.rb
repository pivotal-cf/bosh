require 'spec_helper'

describe VSphereCloud::Cloud do

  let(:config) {
    {
        'vcenters' => [{
                           'host' => 'host',
                           'user' => 'user',
                           'password' => 'password',
                           'datacenters' => [{
                                                 'name' => 'name',
                                                 'template_folder' => 'template_folder',
                                                 'vm_folder' => 'vm_folder',
                                                 'datastore_pattern' => 'datastore_pattern',
                                                 'persistent_datastore_pattern' => 'persistent_datastore_pattern',
                                                 'disk_path' => 'disk_path',
                                                 'clusters' => []
                                             }]
                       }],
        'agent' => {},
    }
  }

  let(:client) { double(VSphereCloud::Client) }
  
  subject(:vsphere_cloud) { described_class.new(config) }

  describe '#fix_device_unit_numbers' do
    let(:device_class) { Struct.new(:unit_number, :controller_key) }
    let(:device_change_class) { Struct.new(:device) }
    let(:dnil) { device_class.new(nil, 0) }

    def self.it_assigns_available_unit_numbers_for_devices_in_change_set
      it 'assigns available unit numbers for devices in change set' do
        vsphere_cloud.fix_device_unit_numbers(devices, device_changes)

        devices.each do |d|
          expect((0..15).to_a).to include(d.unit_number) if d.controller_key
        end

        device_changes.map(&:device).each do |d|
          expect((0..15).to_a).to include(d.unit_number) if d.controller_key
        end
      end
    end

    context 'when no devices' do
      let(:device_change) { device_change_class.new(dnil) }
      let(:devices) { [] }
      let(:device_changes) { [device_change] }
      it_assigns_available_unit_numbers_for_devices_in_change_set
    end

    context 'when a device has unit number 15 and a change has nil for same cont' do
      let(:d15) { device_class.new(15, 0) }
      let(:devices) { [d15] }
      let(:device_change) { device_change_class.new(dnil) }
      let(:device_changes) { [device_change] }
      it_assigns_available_unit_numbers_for_devices_in_change_set
    end

    context 'when all unit number slots in controller are full' do
      let(:devices) do
        (0..15).map { |x| device_class.new(x, 0) }
      end

      let(:device_change) { device_change_class.new(dnil) }
      let(:device_changes) { [device_change] }

      it 'raises error with the device inspected' do
        expect {
          vsphere_cloud.fix_device_unit_numbers(devices, device_changes)
        }.to raise_error(RuntimeError, /No available unit numbers for device: .*struct unit_number=nil, controller_key=0/)
      end
    end

    context 'when there are multiple controller_keys on the devices' do
      let(:devices) do
        [
          device_class.new(1, 0),
          device_class.new(1, 1),
          device_class.new(4, 0),
          device_class.new(5, 1),
          device_class.new(nil, 0),
          device_class.new(nil, 1),
          device_class.new(14, 0),
          device_class.new(15, 1),
          device_class.new(1, nil),
          device_class.new(4, nil),
          device_class.new(nil, 0),
          device_class.new(nil, nil),
        ]
      end

      let(:device_changes) do
        devices.values_at(2, 4, 5, 7, 8, 9, 10, 11).map do |device|
          device_change_class.new(device)
        end
      end

      it 'assigns available unit numbers for devices in change set' do
        vsphere_cloud.fix_device_unit_numbers(devices, device_changes)

        expect(devices[0].to_a).to eq [1, 0]
        expect(devices[1].to_a).to eq [1, 1]
        expect(devices[2].to_a).to eq [4, 0]
        expect(devices[3].to_a).to eq [5, 1]
        expect(devices[4].to_a).to eq [0, 0]
        expect(devices[5].to_a).to eq [0, 1]
        expect(devices[6].to_a).to eq [14, 0]
        expect(devices[7].to_a).to eq [15, 1]
        expect(devices[8].to_a).to eq [1, nil]
        expect(devices[9].to_a).to eq [4, nil]
        expect(devices[10].to_a).to eq [2, 0]
        expect(devices[11].to_a).to eq [nil, nil]
      end
    end
  end

  before(:each) do
    client.stub(:login)
    client.stub_chain(:stub, :cookie).and_return('a=1')

    described_class.any_instance.stub(:setup_at_exit)

    VSphereCloud::Client.stub(new: client)
  end

  describe 'has_vm?' do

    let(:vm_id) { 'vm_id' }

    context 'the vm is found' do

      it 'returns true' do
        subject.should_receive(:get_vm_by_cid).with(vm_id)
        expect(subject.has_vm?(vm_id)).to be_true
      end
    end

    context 'the vm is not found' do

      it 'returns false' do
        subject.should_receive(:get_vm_by_cid).with(vm_id).and_raise(Bosh::Clouds::VMNotFound)
        expect(subject.has_vm?(vm_id)).to be_false
      end


    end

  end

  describe 'snapshot_disk' do
    it 'raises not implemented exception when called' do
      expect {subject.snapshot_disk('123')}.to raise_error(Bosh::Clouds::NotImplemented)
    end
  end

  describe ''


end
