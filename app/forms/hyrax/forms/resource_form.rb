# frozen_string_literal: true

module Hyrax
  module Forms
    ##
    # @api public
    #
    # @example defining a form class using HydraEditor-like configuration
    #   class MonographForm < Hyrax::Forms::ResourceForm(Monograph)
    #     self.required_fields = [:title, :creator, :rights_statement]
    #     # other WorkForm-like configuration here
    #   end
    #
    def self.ResourceForm(work_class)
      Class.new(Hyrax::Forms::ResourceForm) do
        self.model_class = work_class

        include Hyrax::FormFields(:core_metadata)
      end
    end

    ##
    # @api public
    #
    # This form wraps `Hyrax::ChangeSet` in the `HydraEditor::Form` interface.
    class ResourceForm < Hyrax::ChangeSet
      ##
      # Nested form for permissions.
      #
      # @note due to historical oddities with Hydra::AccessControls and Hydra
      #   Editor, Hyrax's views rely on `agent_name` and `access` as field
      #   names. we provide these as virtual fields andprepopulate these from
      #   `Hyrax::Permission`.
      class Permission < Hyrax::ChangeSet
        property :agent_name, virtual: true, prepopulator: ->(_opts) { self.agent_name = model.agent }
        property :access, virtual: true, prepopulator: ->(_opts) { self.access = model.mode }
      end

      class_attribute :model_class

      delegate :depositor, :human_readable_type, to: :model

      property :visibility # visibility has an accessor on the model

      property :agreement_accepted, virtual: true, default: false, prepopulator: ->(_opts) { self.agreement_accepted = !model.new_record }

      collection :permissions, virtual: true, default: [], form: Permission, prepopulator: ->(_opts) { self.permissions = Hyrax::AccessControl.for(resource: model).permissions }

      # virtual properties for embargo/lease;
      property :embargo_release_date, virtual: true, prepopulator: ->(_opts) { self.embargo_release_date = model.embargo&.embargo_release_date }
      property :visibility_after_embargo, virtual: true, prepopulator: ->(_opts) { self.visibility_after_embargo = model.embargo&.visibility_after_embargo }
      property :visibility_during_embargo, virtual: true, prepopulator: ->(_opts) { self.visibility_during_embargo = model.embargo&.visibility_during_embargo }

      property :lease_expiration_date, virtual: true,  prepopulator: ->(_opts) { self.lease_expiration_date = model.lease&.lease_expiration_date }
      property :visibility_after_lease, virtual: true, prepopulator: ->(_opts) { self.visibility_after_lease = model.lease&.visibility_after_lease }
      property :visibility_during_lease, virtual: true, prepopulator: ->(_opts) { self.visibility_during_lease = model.lease&.visibility_during_lease }

      # pcdm relationships
      property :admin_set_id

      class << self
        ##
        # @api public
        #
        # Factory for generic, per-work froms
        #
        # @example
        #   monograph  = Monograph.new
        #   change_set = Hyrax::Forms::ResourceForm.for(monograph)
        def for(work)
          "#{work.class}Form".constantize.new(work)
        rescue NameError => _err
          Hyrax::Forms::ResourceForm(work.class).new(work)
        end

        ##
        # @return [Array<Symbol>] list of required field names as symbols
        def required_fields
          definitions
            .select { |_, definition| definition[:required] }
            .keys.map(&:to_sym)
        end

        ##
        # @param [Enumerable<#to_s>] fields
        #
        # @return [Array<Symbol>] list of required field names as symbols
        def required_fields=(fields)
          fields = fields.map(&:to_s)
          raise(KeyError) unless fields.all? { |f| definitions.key?(f) }

          fields.each { |field| definitions[field].merge!(required: true) }

          required_fields
        end
      end

      ##
      # @param [#to_s] attr
      # @param [Object] value
      #
      # @return [Object] the set value
      def []=(attr, value)
        public_send("#{attr}=".to_sym, value)
      end

      ##
      # @deprecated use model.class instead
      #
      # @return [Class]
      def model_class # rubocop:disable Rails/Delegate
        model.class
      end

      ##
      # @return [Array<Symbol>] terms for display 'above-the-fold', or in the most
      #   prominent form real estate
      def primary_terms
        _form_field_definitions
          .select { |_, definition| definition[:primary] }
          .keys.map(&:to_sym)
      end

      ##
      # @return [Array<Symbol>] terms for display 'below-the-fold'
      def secondary_terms
        _form_field_definitions
          .select { |_, definition| definition[:display] && !definition[:primary] }
          .keys.map(&:to_sym)
      end

      ##
      # @return [Boolean] whether there are terms to display 'below-the-fold'
      def display_additional_fields?
        secondary_terms.any?
      end

      private

        def _form_field_definitions
          self.class.definitions
        end
    end
  end
end
