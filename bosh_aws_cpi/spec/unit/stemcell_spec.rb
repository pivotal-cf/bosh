require 'spec_helper'

describe Bosh::AwsCloud::Stemcell do
  describe ".find" do
    it "should return an AMI if given an id for an existing one" do
      fake_aws_ami = double("image", exists?: true)
      region = double("region", images: {'ami-exists' => fake_aws_ami})
      described_class.find(region, "ami-exists").ami.should == fake_aws_ami
    end

    it "should raise an error if no AMI exists with the given id" do
      fake_aws_ami = double("image", exists?: false)
      region = double("region", images: {'ami-doesntexist' => fake_aws_ami})
      expect {
        described_class.find(region, "ami-doesntexist")
      }.to raise_error Bosh::Clouds::CloudError, "could not find AMI ami-doesntexist"
    end
  end

  describe "#create" do
    context "with real stemcell" do
      it "should turn it into an ami"
    end

    context "with light stemcell" do
      it "should register an existing ami"
    end
  end

  describe "#delete" do
    let(:fake_aws_ami) { double("image", exists?: true) }
    let(:region) { double("region", images: {'ami-exists' => fake_aws_ami}) }

    context "with real stemcell" do
      it "should deregister the ami" do
        stemcell = described_class.new(region, fake_aws_ami)

        stemcell.stub(:fake? => false)
        stemcell.stub(:memoize_snapshots)
        fake_aws_ami.should_receive(:deregister).ordered
        stemcell.should_receive(:wait_resource).with(fake_aws_ami, :deleted).ordered
        stemcell.should_receive(:delete_snapshots).ordered

        stemcell.delete
      end
    end

    context "with light stemcell" do
      it "should fake ami deregistration" do
        stemcell = described_class.new(region, fake_aws_ami)

        stemcell.stub(:fake? => true)
        fake_aws_ami.should_not_receive(:deregister).ordered

        stemcell.delete
      end
      # AWS::EC2::Errors::AuthFailure
    end
  end

end