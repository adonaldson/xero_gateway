module XeroGateway
  class Payment
    include Money
    include Dates

    GUID_REGEX = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/ unless defined?(GUID_REGEX)

    # Xero::Gateway associated with this payment.
    attr_accessor :gateway

    # Any errors that occurred when the #valid? method called.
    attr_reader :errors
    
    # All accessible fields
    attr_accessor :invoice_id, :invoice_number, :account_id, :account_code, :payment_id, :date, :amount, :reference, :currency_rate


    def initialize(params = {})
      @errors ||= []

      params.each do |k,v|
        self.send("#{k}=", v)
      end
    end

    # Validate the Payment record according to what will be valid by the gateway.
    #
    # Usage: 
    #  payment.valid?     # Returns true/false
    #  
    #  Additionally sets payment.errors array to an array of field/error.
    def valid?
      @errors = []

      ensure_invoice_id_is_a_valid_guid_or_blank
      ensure_invoice_id_or_number_is_set
      ensure_account_id_is_a_valid_guid_or_blank
      ensure_account_id_or_code_is_set

      @errors.size == 0
    end

    # Creates this payment record (using gateway.create_payment) with the associated gateway.
    # If no gateway set, raise a NoGatewayError exception.
    def create
      raise NoGatewayError unless gateway
      gateway.create_payment(self)
    end

    # Alias save as create as this is currently the only write action.
    alias_method :save, :create

    def to_xml(b = Builder::XmlMarkup.new)
      b.Payment {
        b.Invoice {
          b.InvoiceID invoice_id if invoice_id
          b.InvoiceNumber invoice_number if invoice_number
        }
        b.Account {
          b.AccountID account_id if account_id
          b.Code account_code if account_code
        }
        b.Date Payment.format_date(self.date || Date.today)
        b.Amount self.amount if self.amount
        b.Reference reference if reference
        b.CurrencyRate currency_rate if currency_rate
      }
    end

    def self.from_xml(payment_element)
      payment = Payment.new
      payment_element.children.each do | element |
        case element.name
          when 'InvoiceID'      then payment.invoice_id = element.text
          when 'InvoiceNumber'  then payment.invoice_number = element.text
          when 'AccountID'      then payment.account_id = element.text
          when 'Code'           then payment.account_code = element.text
          when 'PaymentID'      then payment.payment_id = element.text
          when 'Date'           then payment.date = parse_date_time(element.text)
          when 'Amount'         then payment.amount = BigDecimal.new(element.text)
          when 'Reference'      then payment.reference = element.text
          when 'CurrencyRate'   then payment.currency_rate = BigDecimal.new(element.text)
        end    
      end
      payment
    end 
    
    def ==(other)
      [:invoice_id, :invoice_number, :account_id, :account_code, :payment_id, :date, :amount, :reference, :currency_rate].each do |field|
        return false if send(field) != other.send(field)
      end
      return true
    end

    private

    def ensure_invoice_id_is_a_valid_guid_or_blank
      if !invoice_id.nil? && invoice_id !~ GUID_REGEX
        @errors << ['invoice_id', 'must be blank or a valid Xero GUID']
      end
    end

    def ensure_invoice_id_or_number_is_set
      if invoice_id.blank? && invoice_number.blank?
        @errors << ['invoice_id', 'must set an Invoice ID or Number']
        @errors << ['invoice_name', 'must set an Invoice ID or Number']
      end
    end

    def ensure_account_id_is_a_valid_guid_or_blank
      if !account_id.nil? && account_id !~ GUID_REGEX
        @errors << ['account_id', 'must be a valid Xero GUID']
      end
    end

    def ensure_account_id_or_code_is_set
      if account_id.blank? && account_code.blank?
        @errors << ['account_id', 'must set an Account ID or Code']
        @errors << ['account_code', 'must set an Account ID or Code']
      end
    end

  end
end
