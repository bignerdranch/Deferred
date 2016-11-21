module Fastlane
  module Actions
    class PodspecSetVersionAction < Action
      def self.run(params)
        Actions.verify_gem!('semantic')
        require 'semantic'

        podspec_path = params[:path]
        UI.user_error!("Could not find podspec file at path #{podspec_path}") unless File.exist? podspec_path

        if params[:version]
          semver = params[:version]
        else
          semver = Semantic::Version.new params[:version_number]
        end

        podspec_content = File.read(podspec_path)
        podspec_content = podspec_content.gsub(/^([^#]*version\s+=\s+['"])\S*(['"])/i, "\\1#{semver}\\2")

        File.write(podspec_path, podspec_content)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Set the version in a podspec file"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       description: "You must specify the path to the podspec file to update",
                                       default_value: Dir["*.podspec"].last,
                                       verify_block: proc do |value|
                                         UI.user_error!("Please pass a 'path' to the action") if value.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :version_number,
                                       optional: true,
                                       description: "Version as text",
                                       conflicting_options: [:version],
                                       conflict_block: proc do |option|
                                         UI.user_error!("You can only pass either a 'version' or a '#{value.key}', not both") unless option.value.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       type: Semantic::Version,
                                       optional: true,
                                       description: "Version as version object",
                                       conflicting_options: [:version_number],
                                       conflict_block: proc do |option|
                                         UI.user_error!("You can only pass either a 'version_number' or a '#{option.key}', not both") unless option.value.length == 0
                                       end)
        ]
      end

      def self.authors
        ["Liquidsoul", "KrauseFx", "zwaldowski"]
      end

      def self.example_code
        [ 'podspec_set_version(path: "BNRDeferred.podspec", version_number: "3.0.0-beta.1")' ]
      end

      def self.is_supported?(platform)
        platform != :android
      end
    end
  end
end
