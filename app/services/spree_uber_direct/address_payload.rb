module SpreeUberDirect
  # Shared address/phone formatting between Quote (create_quote) and
  # DeliveryDispatcher (create_delivery) — both build a payload from the
  # same order + fulfilling StockLocation shape, and Uber's schema uses
  # the identical JSON-string-address / E.164-phone conventions on both
  # endpoints (confirmed directly against the real openapi.yaml).
  module AddressPayload
    module_function

    # Same E.164 normalization as SpreeDoordash::Quote#format_phone
    # (Uber's own schema pattern, `^\+[0-9]+$`, is the same shape DoorDash
    # rejects anything else against) — US-only, matching the rest of this
    # demo.
    def format_phone(raw)
      digits = raw.to_s.gsub(/\D/, '')
      digits = "1#{digits}" if digits.length == 10
      "+#{digits}"
    end

    # Uber wants a JSON *string* per address field — structured, not
    # DoorDash's flat comma-joined string. Spree::StockLocation and
    # Spree::Address share the same field shape (address1/address2/city/
    # state/zipcode/country) even though they're unrelated classes.
    def format_address(record)
      street = [record.address1, record.try(:address2)].compact_blank
      {
        street_address: street,
        city: record.city,
        state: record.state&.abbr || record.state_name,
        zip_code: record.zipcode,
        country: record.country&.iso
      }.compact.to_json
    end
  end
end
