# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

describe Bosh::Cli::Command::Stemcell do
  subject do
    Bosh::Cli::Command::Stemcell.new.tap do |cmd|
      cmd.stub(target: "test")
      cmd.stub(username: "user")
      cmd.stub(password: "pass")
      cmd.stub(director: director)
    end
  end

  let(:director) { mock(Bosh::Cli::Director) }

  describe "upload a stemcell" do
    before { subject.stub(cache: Bosh::Cli::Cache.new(Dir.mktmpdir)) }
    let(:tarball_path) { spec_asset("valid_stemcell.tgz") }

    context "when stemcell does not exist" do
      before { director.stub(list_stemcells: []) }

      it "uploads stemcell and returns successfully" do
        director.should_receive(:upload_stemcell).with(tarball_path)
        subject.upload(tarball_path)
      end
    end

    context "when stemcell already exists" do
      before { director.stub(list_stemcells: [{"name" => "ubuntu-stemcell", "version" => 1}]) }

      context "when --skip-if-exists flag is given" do
        before { subject.add_option(:skip_if_exists, true) }

        it "does not upload stemcell" do
          director.should_not_receive(:upload_stemcell)
          subject.upload(tarball_path)
        end

        it "returns successfully" do
          expect {
            subject.upload(tarball_path)
          }.to_not raise_error
        end
      end

      context "when --skip-if-exists flag is not given" do
        it "does not upload stemcell" do
          director.should_not_receive(:upload_stemcell)
          subject.upload(tarball_path) rescue nil
        end

        it "raises an error" do
          expect {
            subject.upload(tarball_path)
          }.to raise_error(Bosh::Cli::CliError, /already exists/)
        end
      end
    end
  end
end
