module Bosh::AwsCloud
  class Stemcell
    include Helpers

    attr_reader :ami

    def self.find(region, id)
      image = region.images[id]
      raise Bosh::Clouds::CloudError, "could not find AMI #{id}" unless image.exists?
      new(region, image)
    end

    def initialize(region, image)
      @region = region
      @ami = image
      @snapshots = []
      @logger = Bosh::Clouds::Config.logger
    end

    def delete
      return if fake?

      memoize_snapshots

      ami.deregister
      wait_resource(ami, :deleted)

      delete_snapshots
    end

    def root_device_name
      ami.root_device_name
    end

    def memoize_snapshots
      ami.block_device_mappings.to_h.each do |device, map|
        id = map[:snapshot_id]
        if id
          @logger.debug("queuing snapshot #{id} for deletion")
          @snapshots << id
        end
      end
    end

    def delete_snapshots
      @snapshots.each do |id|
        @logger.info("cleaning up snapshot #{id}")
        snapshot = @region.snapshots[id]
        snapshot.delete
      end
    end

    def fake?
      # iam.client.get_user[:user][:user_id]
      # Options:
      # 1) Check for the image owner id
      # 2) Tag the ami
      # 3) Try to delete the image (catch AuthFail)
    end
  end
end
