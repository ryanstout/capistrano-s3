require 'aws/s3'
require 'mime/types'

module Publisher

  LAST_PUBLISHED_FILE = '.last_published'

  def self.publish!(key, secret, bucket, source, extra_options)
    s3 = self.establish_connection!(key, secret)

    self.files(source).each do |file|
      if !File.directory?(file)
        next if self.published?(file)

        path = self.base_file_path(source, file)
        path.gsub!(/^\//, "") # Remove preceding slash for S3

        contents = open(file)

        types = MIME::Types.type_for(File.basename(file))
        if types.empty?
          options = {
            :acl => :public_read
          }
        else
          options = {
            :acl => :public_read,
            :content_type => types[0]
          }
        end
        options.merge!(extra_options)
        s3.buckets[bucket].objects[path].write(contents, options)
      end
    end

    FileUtils.touch(LAST_PUBLISHED_FILE)
  end

  def self.clear!(key, secret, bucket)    
    s3 = self.establish_connection!(key, secret)
    s3.buckets[bucket].clear!
  end

  private

    # Establishes the connection to Amazon S3
    def self.establish_connection!(key, secret)
      # Send logging to STDOUT
      AWS.config(:logger => Logger.new(STDOUT))
      AWS::S3.new(
        :access_key_id => key,
        :secret_access_key => secret
      )
    end

    def self.base_file_path(root, file)
      file.gsub(root, "")
    end
  
    def self.files(deployment_path)
      Dir.glob("#{deployment_path}/**/*")
    end

    def self.published?(file)
      File.mtime(file) < File.mtime(LAST_PUBLISHED_FILE)
    end
end