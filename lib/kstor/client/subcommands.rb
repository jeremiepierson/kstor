# frozen_string_literal: true

module KStor
  module Client
    # Sub-commands that can be invoked from the command-line.
    module SubCommands
      # Create a user group.
      def group_create
        request('group_create') do |o|
          o.string('-n', '--name', 'Group name')
        end
      end

      # Rename a group.
      def group_rename
        request('group_rename') do |o|
          o.integer('-g', '--group-id', 'ID of group to rename')
          o.string('-n', '--name', 'New name of group')
        end
      end

      # Delete a group
      def group_delete
        request('group_delete') do |o|
          o.integer('-g', '--group-id', 'ID of group to delete')
        end
      end

      # Search groups by name.
      def group_search
        request('group_search') do |o|
          o.string('-n', '--name', 'Name or wildcard to search')
        end
      end

      # Get info on a group
      def group_get
        request('group_get') do |o|
          o.integer('-g', '--group-id', 'ID of group to show')
        end
      end

      # Add user to group
      def group_add_user
        request('group_add_user') do |o|
          o.integer('-g', '--group-id', 'ID of group to extend')
          o.integer('-u', '--user-id', 'ID of user to add')
        end
      end

      # Remove user from group
      def group_remove_user
        request('group_remove_user') do |o|
          o.integer('-g', '--group-id', 'ID of group to shrink')
          o.integer('-u', '--user-id', 'ID of user to remove')
        end
      end

      # Create user
      def user_create
        request('user_create') do |o|
          o.string('-l', '--user-login', 'Login of new user')
          o.string('-n', '--user-name', 'Name of new user')
          o.integer(
            '-t', '--token-lifespan', 'Validity of token in seconds',
            default: 60 * 60
          )
        end
      end

      # Activate new user.
      def user_activate
        request('user_activate') do |o|
          o.string('-t', '--token', 'activation token')
        end
      end

      # Change password.
      def user_change_password
        request('user_change_password') do |o|
          o.string('-p', '--new-password', 'New password')
        end
      end

      # Create a secret.
      def secret_create
        request_with_meta('secret_create') do |o|
          o.string('-p', '--plaintext', 'Value of the secret')
          o.array('-g', '--group_ids', 'Groups that can unlock the secret')
          o.string('-a', '--app', 'application of this secret')
          o.string('-d', '--database', 'database of this secret')
          o.string('-l', '--login', 'login of this secret')
          o.string('-S', '--server', 'server of this secret')
          o.string('-u', '--url', 'url for this secret')
        end
      end

      # Return a list of matching secrets.
      def secret_search
        request_with_meta('secret_search') do |o|
          o.string('-a', '--app', 'secrets for this application')
          o.string('-d', '--database', 'secrets for this database')
          o.string('-l', '--login', 'secrets for this login')
          o.string('-s', '--server', 'secrets for this server')
          o.string('-u', '--url', 'secrets for this url')
        end
      end

      # Decrypt secret value and metadata
      def secret_unlock
        request('secret_unlock') do |o|
          o.string('-s', '--secret-id', 'secret ID to unlock')
        end
      end

      # Update secret metadata
      def secret_update_meta
        request_with_meta('secret_update_meta') do |o|
          o.string('-s', '--secret-id', 'secret ID to modify')
          o.string('-a', '--app', 'new application of this secret')
          o.string('-d', '--database', 'new database of this secret')
          o.string('-l', '--login', 'new login of this secret')
          o.string('-S', '--server', 'new server of this secret')
          o.string('-u', '--url', 'new url for this secret')
        end
      end

      # Update secret value
      def secret_update_value
        request('secret_update_value') do |o|
          o.string('-s', '--secret-id', 'secret ID to modify')
          o.string('-p', '--plaintext', 'new plaintext value')
        end
      end

      # Delete secret
      def secret_delete
        request('secret_delete') do |o|
          o.string('-s', '--secret-id', 'secret ID to delete')
        end
      end
    end
  end
end
