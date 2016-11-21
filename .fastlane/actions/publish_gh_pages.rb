module Fastlane
  module Actions
    class PublishGhPagesAction < Action
      def self.run(params)
        git = "git -C #{params[:path].shellescape}"

        sh "#{git} init"

        if params[:author_name]
          sh "#{git} config user.name #{params[:author_name].shellescape}"
        end

        if params[:author_email]
          sh "#{git} config user.email #{params[:author_email].shellescape}"
        end

        sh "#{git} add -A"

        commit_message = "Publish from #{Actions.last_git_commit_dict[:abbreviated_commit_hash]} of #{Actions.git_branch}"
        sh "#{git} commit -m #{commit_message.shellescape} || true"

        remote = URI(sh('git remote get-url origin').strip)
        if params[:github_token]
          remote.userinfo = params[:github_token]
        end

        UI.command("#{git} push [[REDACTED]]")

        Actions.sh_control_output("#{git} push --force #{remote.to_s.shellescape} master:gh-pages",
          print_command: false, print_command_output: false,
          error_callback: proc do |error|
            if params[:github_token]
              UI.error(error.gsub(params[:github_token], '[[GITHUB_TOKEN]]'))
            else
              UI.error(message)
            end
        end)
      end

      #####################################################
      # @!group Documentation
      #####################################################

      def self.description
        "Publishes a given directory as the root of gh-pages"
      end

      def self.available_options
        [
          FastlaneCore::ConfigItem.new(key: :path,
                                       description: "You must specify the path to the directory to upload",
                                       default_value: "",
                                       verify_block: proc do |value|
                                         UI.user_error!("Please pass a 'path' to the action") if value.length == 0
                                         UI.user_error!("Not a directory at '#{value}'") unless File.directory?(value)
                                       end),
          FastlaneCore::ConfigItem.new(key: :github_token,
                                       env_name: "GITHUB_API_TOKEN",
                                       description: "Personal API token for pushing to GitHub - generate one at https://github.com/settings/tokens",
                                       type: String,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :author_name,
                                       description: "Git author name to use instead of the current user",
                                       type: String,
                                       optional: true),
          FastlaneCore::ConfigItem.new(key: :author_email,
                                       description: "Git author email to use instead of the current email",
                                       type: String,
                                       optional: true)
        ]
      end

      def self.authors
        ["zwaldowski"]
      end

      def self.is_supported?(platform)
        return true
      end
    end
  end
end
