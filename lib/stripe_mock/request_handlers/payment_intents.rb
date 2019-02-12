module StripeMock
  module RequestHandlers
    module PaymentIntents

      def PaymentIntents.included(klass)
        klass.add_handler 'post /v1/payment_intents',                 :new_payment_intent
        klass.add_handler 'get /v1/payment_intents/([^/]*)',          :get_payment_intent
        klass.add_handler 'post /v1/payment_intents/([^/]*)/confirm', :confirm_payment_intent
        if false
        klass.add_handler 'post /v1/customers/([^/]*)',             :update_customer
        klass.add_handler 'delete /v1/customers/([^/]*)',           :delete_customer
        klass.add_handler 'get /v1/customers',                      :list_customers
        end
      end

      def new_payment_intent(route, method_url, params, headers)
        params[:id] ||= new_id('pi')
        raise 'Unexpected parameter "source"' if params[:source]
        raise 'Unexpected parameter "confirm"' if params[:confirm]
        raise 'Unexpected parameter "return_url"' if params[:return_url]
        raise 'Unexpected parameter "save_source_to_customer"' if params[:save_source_to_customer]

        payment_intents[ params[:id] ] = Data.mock_payment_intent(params)
      end

      def get_payment_intent(route, method_url, params, headers)
        route =~ method_url
        payment_intent = assert_existence :payment_intent, $1, payment_intents[$1]

        payment_intent
      end

      def confirm_payment_intent(route, method_url, params, headers)
        route =~ method_url
        payment_intent = assert_existence :payment_intent, $1, payment_intents[$1]

        amount = payment_intent[:amount]
        charge_params = { id: new_id('ch'), amount: amount }
        if source_data = params[:source_data]
          if token = source_data[:token]
            source = charge_params[:source] = Data.mock_source_from_token(token, payment_intent[:customer])
            if source_data[:save_source_to_customer]
              customer_id = payment_intent[:customer]
              customer = customers[customer_id]
              customer[:sources][:data] << source
            end
          end
        end
        charge = Data.mock_charge(charge_params)
        charges[charge[:id]] = charge
        payment_intent[:charges][:data].unshift charge
        payment_intent[:charges][:total_count] = payment_intent[:charges][:data].size
        if charge[:status] == 'succeeded'
          payment_intent[:amount_received] = amount
          payment_intent[:status] = 'succeeded'
        end
        payment_intent
      end

      if false
      def update_customer(route, method_url, params, headers)
        route =~ method_url
        cus = assert_existence :customer, $1, customers[$1]

        # Delete those params if their value is nil. Workaround of the problematic way Stripe serialize objects
        params.delete(:sources) if params[:sources] && params[:sources][:data].nil?
        params.delete(:subscriptions) if params[:subscriptions] && params[:subscriptions][:data].nil?
        # Delete those params if their values aren't valid. Workaround of the problematic way Stripe serialize objects
        if params[:sources] && !params[:sources][:data].nil?
          params.delete(:sources) unless params[:sources][:data].any?{ |v| !!v[:type]}
        end
        if params[:subscriptions] && !params[:subscriptions][:data].nil?
          params.delete(:subscriptions) unless params[:subscriptions][:data].any?{ |v| !!v[:type]}
        end
        cus.merge!(params)

        if params[:source]
          if params[:source].is_a?(String)
            new_card = get_card_or_bank_by_token(params.delete(:source))
          elsif params[:source].is_a?(Hash)
            unless params[:source][:object] && params[:source][:number] && params[:source][:exp_month] && params[:source][:exp_year]
              raise Stripe::InvalidRequestError.new('You must supply a valid card', nil, http_status: 400)
            end
            new_card = card_from_params(params.delete(:source))
          end
          add_card_to_object(:customer, new_card, cus, true)
          cus[:default_source] = new_card[:id]
        end

        if params[:coupon]
          coupon = coupons[ params[:coupon] ]
          assert_existence :coupon, params[:coupon], coupon

          add_coupon_to_customer(cus, coupon)
        end

        cus
      end

      def delete_customer(route, method_url, params, headers)
        route =~ method_url
        assert_existence :customer, $1, customers[$1]

        customers[$1] = {
          id: customers[$1][:id],
          deleted: true
        }
      end

      def list_customers(route, method_url, params, headers)
        Data.mock_list_object(customers.values, params)
      end
      end
    end
  end
end
