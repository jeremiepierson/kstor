# frozen_string_literal: true

module KStor
  module Model
    # Metadata for a secret.
    #
    # This is not a "real" model object: just a helper class to convert
    # metadata to and from database.
    class SecretMeta
      # Secret is defined for this application
      attr_accessor :app
      # Secret is defined for this database
      attr_accessor :database
      # Secret is defined for this login
      attr_accessor :login
      # Secret is related to this server
      attr_accessor :server
      # Secret should be used at this URL
      attr_accessor :url

      # Create new metadata for a secret.
      #
      # Hash param can contains keys for "app", "database", "login", "server"
      # and "url". Any other key is ignored.
      #
      # @param values [Hash, KStor::Crypto::ArmoredHash] metadata
      # @return [KStor::Model::SecretMeta] secret metadata
      def initialize(values)
        @app = values['app']
        @database = values['database']
        @login = values['login']
        @server = values['server']
        @url = values['url']
      end

      # Convert this metadata to a Hash.
      #
      # Empty values will not be included.
      #
      # @return [Hash[String, String]] metadata as a Hash
      def to_h
        { 'app' => @app, 'database' => @database, 'login' => @login,
          'server' => @server, 'url' => @url }.compact
      end

      # Prepare metadata to be written to disk or database.
      #
      # @return [KStor::Crypto::ArmoredHash] serialized metadata
      def serialize
        Crypto::ArmoredHash.from_hash(to_h)
      end

      # Merge metadata.
      #
      # @param other [KStor::Model::SecretMeta] other metadata that will
      #   override this object's values.
      def merge(other)
        values = to_h.merge(other.to_h)
        values.reject! { |_, v| v.empty? }
        self.class.new(values)
      end

      # Match against wildcards.
      #
      # Metadata will be matched against another metadata object with wildcard
      # values. This uses roughly the same rules that shell wildcards (e.g.
      # fnmatch(3) C function).
      #
      # @see File.fnmatch?
      #
      # @param meta [KStor::Model::SecretMeta] wildcard metadata
      # @return [Boolean] true if matched
      # rubocop:disable Metrics/CyclomaticComplexity
      def match?(meta)
        self_h = to_h
        other_h = meta.to_h
        other_h.each do |k, wildcard|
          val = self_h[k]
          return false if val.nil? && !wildcard.nil? && wildcard != '*'
          next if val.nil?
          next if wildcard.nil?

          key_matched = File.fnmatch?(
            wildcard, val, File::FNM_CASEFOLD | File::FNM_DOTMATCH
          )
          return false unless key_matched
        end
        true
      end
      # rubocop:enable Metrics/CyclomaticComplexity
    end
  end
end
