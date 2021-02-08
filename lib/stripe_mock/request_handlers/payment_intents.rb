module StripeMock
  module RequestHandlers
    module PaymentIntents

      def PaymentIntents.included(klass)
        klass.add_handler 'post /v1/payment_intents',                 :new_payment_intent
        klass.add_handler 'get /v1/payment_intents/([^/]*)',          :get_payment_intent
        klass.add_handler 'post /v1/payment_intents/([^/]*)/confirm', :confirm_payment_intent
        klass.add_handler 'post /v1/payment_intents/([^/]*)/cancel',  :cancel_payment_intent
      end

      def new_payment_intent(route, method_url, params, headers)
        params[:id] ||= new_id('pi')
        raise 'Unexpected parameter "source"' if params[:source]
        raise 'Unexpected parameter "confirm"' if params[:confirm]
        raise 'Unexpected parameter "return_url"' if params[:return_url]
        raise 'Unexpected parameter "save_payment_method"' if params[:save_payment_method]

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
        charge_params = { id: new_id('ch'), amount: amount, currency: payment_intent[:currency] }
        if source_data = params[:source_data]
          if token = source_data[:token]
            source = charge_params[:source] = Data.mock_source_from_token(token, payment_intent[:customer])
            if source_data[:save_payment_method]
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

      def cancel_payment_intent(route, method_url, params, headers)
        route =~ method_url
        payment_intent = assert_existence :payment_intent, $1, payment_intents[$1]

        payment_intent[:status] = 'canceled'
        payment_intent
      end
    end
  end
end
