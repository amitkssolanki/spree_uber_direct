module Spree
  module Admin
    # Plain credential-entry form for the current store's Uber Direct
    # sandbox/production OAuth application — not a "Connect" redirect dance.
    # An admin creates the application in the Direct dashboard
    # (direct.uber.com) once and pastes the values in here directly
    # (encrypted at rest — see SpreeUberDirect::Credential). Same static-form
    # convention as spree_doordash's own credentials controller, even though
    # the underlying auth is OAuth2 under the hood (client_credentials, not
    # an authorization-code redirect).
    class UberDirectCredentialsController < Spree::Admin::BaseController
      def show
        @credential = SpreeUberDirect::Credential.find_or_initialize_by(store: current_store)
      end

      def update
        @credential = SpreeUberDirect::Credential.find_or_initialize_by(store: current_store)

        if @credential.update(credential_params)
          flash[:success] = Spree.t(:uber_direct_credential_saved, default: 'Uber Direct credentials saved.')
        else
          flash[:error] = @credential.errors.full_messages.to_sentence
        end

        redirect_to admin_uber_direct_credential_path
      end

      private

      # Blank secret fields mean "leave unchanged" (the form always renders
      # them empty and never echoes the current value back) — submitting an
      # actually-blank value would otherwise silently overwrite a working
      # credential with an empty string on every save. Also clears the
      # cached access token whenever client_id/client_secret actually
      # change, so a rotated secret takes effect on the very next API call
      # instead of failing against the old token until it naturally expires.
      def credential_params
        permitted = params.require(:spree_uber_direct_credential).permit(
          :client_id, :client_secret, :customer_id, :webhook_signing_secret, :uber_environment
        )
        %i[client_secret webhook_signing_secret].each do |field|
          permitted.delete(field) if permitted[field].blank?
        end
        if permitted[:client_id].present? || permitted[:client_secret].present?
          permitted[:access_token] = nil
          permitted[:access_token_expires_at] = nil
        end
        permitted
      end
    end
  end
end
