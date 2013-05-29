# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Release do
  subject do
    Bosh::Cli::Command::Release.new.tap do |cmd|
      cmd.stub(target: "test")
      cmd.stub(username: "user")
      cmd.stub(password: "pass")
      cmd.stub(director: director)
    end
  end

  let(:director) { mock(Bosh::Cli::Director) }

  describe "upload a release" do
    #before { subject.stub(cache: Bosh::Cli::Cache.new(Dir.mktmpdir)) }
    before { director.stub(match_packages: []) }
    let(:tarball_path) { spec_asset("valid_release.tgz") }

    context "when release does not exist" do
      before { director.stub(:get_release).and_raise(Bosh::Cli::ResourceNotFound) }

      it "uploads release and returns successfully" do
        director.should_receive(:upload_release).with(tarball_path)
        subject.upload(tarball_path)
      end
    end

    context "when release already exists" do
      before { director.stub(get_release:
        {"jobs" => nil, "packages" => nil, "versions" => ["0.1"]}) }

      context "when --skip-if-exists flag is given" do
        before { subject.add_option(:skip_if_exists, true) }

        it "does not upload release" do
          director.should_not_receive(:upload_release)
          subject.upload(tarball_path)
        end

        it "returns successfully" do
          expect {
            subject.upload(tarball_path)
          }.to_not raise_error
        end
      end

      context "when --skip-if-exists flag is not given" do
        it "does not upload release" do
          director.should_not_receive(:upload_release)
          subject.upload(tarball_path) rescue nil
        end

        it "raises an error" do
          expect {
            subject.upload(tarball_path)
          }.to raise_error(Bosh::Cli::CliError, /already been uploaded/)
        end
      end
    end
  end
end
