require 'semantic'

module Fastlane
  module Actions

    class DeferredReadmeSetVersionAction < Action
      def self.run(params)
        readme_path = params[:path]
        UI.user_error!("Could not find README at path #{readme_path}") unless File.exist? readme_path

        if params[:version]
          semver = params[:version]
        else
          semver = Semantic::Version.new params[:version_number]
        end

        readme_content = File.read(readme_path)

        carthage_replacement = semver.pre.nil? ? "~> #{semver.major}.0" : "\"#{semver}\""
        readme_content = readme_content.gsub(/(```\ngithub \"bignerdranch\/Deferred\" )\S*(\n```)/, "\\1#{carthage_replacement}\\2")

        cocoapods_replacement = semver.pre.nil? ? "~> #{semver.major}.0" : "~> #{semver.major}.#{semver.minor}-beta"
        readme_content = readme_content.gsub(/(```ruby\npod 'BNRDeferred', ')\S* \S*('\n```)/, "\\1#{cocoapods_replacement}\\2")

        swiftpm_replacement = "majorVersion: #{semver.major}"
        readme_content = readme_content.gsub(/(\.Package\(url: \"\S*Deferred\S*\", ).*(\),)/, "\\1#{swiftpm_replacement}\\2")

        File.write(readme_path, readme_content)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Set the versions in the Deferred Programming Guide"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       description: "You must specify the path to the README-like file to update",
                                       default_value: "",
                                       verify_block: proc do |value|
                                         UI.user_error!("Please pass a 'path' to the action") if value.length == 0
                                       end),
          FastlaneCore::ConfigItem.new(key: :version_number,
                                       optional: true,
                                       description: "Version as text",
                                       conflicting_options: [:version],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can only pass either a 'version_number' or a '#{value.key}', not both")
                                       end),
          FastlaneCore::ConfigItem.new(key: :version,
                                       optional: true,
                                       description: "Version as version object",
                                       conflicting_options: [:version],
                                       conflict_block: proc do |value|
                                         UI.user_error!("You can only pass either a 'version' or a '#{value.key}', not both")
                                       end)
        ]
      end

      def self.authors
        ["zwaldowski"]
      end

      def self.example_code
        [ 'deferred_readme_set_version(path: "README.md", version_number: "3.0.0-beta.1")' ]
      end
    end
  end
end
