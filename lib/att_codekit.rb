require "json"
require "base64"
require "net/http"
require "uri"
require "resolv"

module ATTCodekit
  VERSION = "0.1.3"

  class Client 

    attr_reader :client_id, :client_secret, :scopes, :access_token, :endpoint_url, :endpoint_host, :endpoint_scheme, :proxy_url, :proxy_port

    # This only assigns values to the appropriate locations.  
    # Call getAccessToken() to pre-populate the access token. 
    # However, an access token will automatically be retrieved before most calls
    
    def initialize(client_id, client_secret, scopes, endpoint_url = "https://api.att.com/", proxy_url = nil)

      raise "client_id must be a 16 or 32 character string" if not client_id.instance_of? String or client_id.nil?
      raise "client_secret must be a 16 or 32 character string" if not client_secret.instance_of? String or client_secret.nil?
      raise "scopes must be a non-empty Array" if not scopes.instance_of?(Array) or scopes.size == 0
      raise "endpoint_url must be a non-empty URL" if !validateString(endpoint_url)

      @client_id = client_id
      @client_secret = client_secret
      @scopes = scopes
      @access_token = nil
      @endpoint_url = endpoint_url

      uri = URI.parse(endpoint_url)

      @endpoint_host = uri.host
      @endpoint_scheme = uri.scheme

      raise "endpoint host must be set" if !validateString(@endpoint_host)
      raise "endpoint scheme must be set" if !validateString(@endpoint_scheme)

      @proxy_url = nil
      @proxy_port = nil

      if( proxy_url != nil && proxy_url.strip.length > 0)
        uri = URI.parse(proxy_url)
        @proxy_url = uri.host
        @proxy_port = uri.port
      else
        begin
          Resolv.getaddress('proxy.entp.attws.com')
          @proxy_url = 'proxy.entp.attws.com'
          @proxy_port = '8080'
        rescue
          # Ignore
        end
      end
    end

    def to_s
      "client_id=#{@client_id}, client_secret=#{@client_secret}, scopes=#{@scopes}, endpoint_url=#{@endpoint_url}"
    end

##########################
# OAUTH
##########################

    # The APIs use the client_credentials and authorization_code grant types.  
    # The authorization_code grant type uses a browser redirect to get user authentication and consent
    # This method creates the URL for the redirect.
    def getAuthCodeUrl(scopes, redirect_uri = nil)
      raise "Authorization code requests require at least one scope" if scopes.length == 0
      if scopes.kind_of? String
         s = scopes
       elsif scopes.kind_of? Array
         s = scopes.scopes.join(',')
       else
         raise "Scopes must be a string or an array"
       end
       if redirect_uri.nil?
         q = "client_id=#{client_id}&scope=#{s}"
       else
         q = "client_id=#{client_id}&scope=#{s}&redirect_uri=#{redirect_uri}"
       end
       
       URI::HTTPS.build(:host => @endpoint_host, :path => "/oauth/authorize", :query => q)
    end

    def getAuthCodeToken(code)

      raise "Auth code tokens require a valid authorization code" if !validateString(code)

      uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/oauth/token"})

      request = Net::HTTP::Post.new( uri.request_uri, 
      initheader = {'Content-Type' => 'application/x-www-form-urlencoded'})

      request.body = "client_id=#{@client_id}&client_secret=#{@client_secret}&grant_type=authorization_code&code=#{code}"
      
      resp = doHttpRequest(uri,request).body
      
      STDERR.puts "getAuthCodeToken: body=#{resp}"
      j = JSON.parse(resp)
      STDERR.puts "getAuthCodeToken: j = #{j}"
      j
    end


    def getAccessToken()

      return @access_token if @access_token != nil

      uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/oauth/token"})

      puts "Get Access Token: Start #{uri}"
      
      request = Net::HTTP::Post.new( uri.request_uri, 
      initheader = {'Content-Type' => 'application/x-www-form-urlencoded'})

      request.body = "client_id=#{@client_id}&client_secret=#{@client_secret}&grant_type=client_credentials&scope=#{scopes.join(',')}"

      puts "Get Access Token: Request"
      
      resp = JSON.parse(doHttpRequest(uri,request).body)

      puts "Get Access Token: Response #{resp}"

      @access_token = resp["access_token"]
    end


    def refreshToken(refreshToken)

      uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/oauth/token"})

      STDOUT.puts "Refresh Token: Start #{uri}"
      
      request = Net::HTTP::Post.new( uri.request_uri, 
      initheader = {'Content-Type' => 'application/x-www-form-urlencoded'})

      q = "client_id=#{@client_id}&client_secret=#{@client_secret}&grant_type=refresh_token&refresh_token=#{refreshToken}"
      request.body = q

      STDOUT.puts "Refresh Token: Request=#{q}"
      
      resp = JSON.parse(doHttpRequest(uri,request).body)

      STDOUT.puts "Refresh Token: Response #{resp}"

      resp
    end


##########################
# PAYMENT
##########################

    def getSinglePayRedirect(amount,category,description,merchantTransactionId,productId,redirectUrl)
      raise "amount must be a positive decimal number" if amount == nil \
      or not /^[0-9]{1,2}.[0-9]{2}$/ =~ amount

      raise "category must be a number between 1 and 5, except 2" if category == nil \
      or !(category.instance_of? Integer or category.instance_of? Fixnum) \
      or category < 1 or category > 5 or category == 2

      raise "description must be a non-empty string" if not validateString(description)

      raise "merchantTransactionId must be a unique value" if not validateString(merchantTransactionId)

      raise "productId must be a non-empty string" if not validateString(productId)

      raise "redirectUrl must be a non-empty string" if not validateString(redirectUrl)

      s = {
        "Amount" => amount,
        "Category" => category,
        "Channel" => "MOBILE_WEB",
        "Description" => description,
        "MerchantTransactionId" => merchantTransactionId,
        "MerchantProductId" => productId,
        "MerchantPaymentRedirectUrl" => redirectUrl
      }.to_json

      resp = doPost( "/Security/Notary/Rest/1/SignedPayload", s, "application/json", "application/json")

      parsed_notary = JSON.parse(resp)

      signedDocument = parsed_notary["SignedDocument"]

      URI::HTTPS.build({:host => @endpoint_host, :path => "/rest/3/Commerce/Payment/Transactions", :query => "Signature=#{parsed_notary["Signature"]}&SignedPaymentDetail=#{parsed_notary["SignedDocument"]}&clientid=#{@client_id}"})

    end

    def getSubscriptionRedirect(amount,category,description,merchantTransactionId,productId,redirectUrl)
      raise "amount must be a positive decimal number" if amount == nil \
      or not /^[0-9]{1,2}.[0-9]{2}$/ =~ amount

      raise "category must be a number between 1 and 5, except 2" if category == nil \
      or !(category.instance_of? Integer or category.instance_of? Fixnum) \
      or category < 1 or category > 5 or category == 2

      raise "description must be a non-empty string" if not validateString(description)

      raise "merchantTransactionId must be a unique value" if not validateString(merchantTransactionId)

      raise "productId must be a non-empty string" if not validateString(productId)

      raise "redirectUrl must be a non-empty string" if not validateString(redirectUrl)

      s = {
        "Amount" => amount,
        "Category" => category,
        "Channel" => "MOBILE_WEB",
        "Description" => description,
        "MerchantTransactionId" => merchantTransactionId,
        "MerchantProductId" => productId,
        "MerchantPaymentRedirectUrl" => redirectUrl,
        "MerchantSubscriptionIdList" => merchantTransactionId[-12..-1], # must be unique
        "IsPurchaseOnNoActiveSubscription" => "false", # Only use false
        "SubscriptionRecurrences" => 99999, # Only use 99999
        "SubscriptionPeriod" => "MONTHLY", # Only use MONTHLY 
        "SubscriptionPeriodAmount" => 1  # Only use 1
        }.to_json

        resp = doPost( "/Security/Notary/Rest/1/SignedPayload", s, "application/json", "application/json")

        parsed_notary = JSON.parse(resp)

        signedDocument = parsed_notary["SignedDocument"]

        URI::HTTPS.build({:host => @endpoint_host, :path => "/rest/3/Commerce/Payment/Subscriptions", :query => "Signature=#{parsed_notary["Signature"]}&SignedPaymentDetail=#{parsed_notary["SignedDocument"]}&clientid=#{@client_id}"})

      end

      def doRefund( id, reasonText = "Customer was not happy" )

        getAccessToken if @access_token == nil

        uri = URI.parse("#{@endpoint_url}/rest/3/Commerce/Payment/Transactions/#{id}?Action=refund")

        request = Net::HTTP::Put.new( uri.request_uri, 
        initheader = { 'Content-type' => 'application/json', 'Accept' => 'application/json', 'Authorization' => "Bearer #{access_token}" })

        request.body = %Q[{ "TransactionOperationStatus":"Refunded","RefundReasonCode":1,"RefundReasonText":"#{reasonText}" }]

        JSON.parse(doHttpRequest(uri,request).body)
      end


      def getTransactionStatus( idType, id )

        raise "Invalid idType" if !["TransactionId","TransactionAuthCode","MerchantTransactionId"].include?(idType)

        getAccessToken if @access_token == nil

        uri = URI.parse("#{@endpoint_url}/rest/3/Commerce/Payment/Transactions/#{idType}/#{id}")

        request = Net::HTTP::Get.new( uri.request_uri, 
        initheader = { 'Accept' => 'application/json', 'Authorization' => "Bearer #{access_token}" })

        JSON.parse(doHttpRequest(uri,request).body)
      end

      def getSubscriptionStatus( idType, id )

        raise "Invalid idType" if !["SubscriptionId","SubscriptionAuthCode","MerchantTransactionId"].include?(idType)

        getAccessToken if @access_token == nil

        uri = URI.parse("#{@endpoint_url}/rest/3/Commerce/Payment/Subscriptions/#{idType}/#{id}")

        request = Net::HTTP::Get.new( uri.request_uri, 
        initheader = { 'Accept' => 'application/json', 'Authorization' => "Bearer #{access_token}" })

        JSON.parse(doHttpRequest(uri,request).body)
      end


      def getNotification( id )

        getAccessToken if @access_token == nil

        uri = URI::HTTPS.build(:host => @endpoint_host, :path => "/rest/3/Commerce/Payment/Notifications/#{id}")

        request = Net::HTTP::Get.new( uri.request_uri, 
        initheader = { 'Accept' => 'application/json', 'Authorization' => "Bearer #{access_token}" })

        resp = doHttpRequest(uri,request)
        body = resp.body
        body
      end


      def acknowledgeNotification( id )

        getAccessToken if @access_token == nil

        uri = URI::HTTPS.build(:host => @endpoint_host, :path => "/rest/3/Commerce/Payment/Notifications/#{id}")

        request = Net::HTTP::Put.new( uri.request_uri, 
        initheader = { 'Authorization' => "Bearer #{access_token}" })

        request.body= ''

        response = doHttpRequest(uri,request)

        response.body
      end

##########################
# SPEECH
##########################

  def postSpeechToText(audioData, fmt, speechContext)
    getAccessToken if @access_token == nil

    uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/speech/v3/speechToText"})

    request = Net::HTTP::Post.new( uri.request_uri, 
      initheader = {'Accept' => 'application/json', 
        'Authorization' => "BEARER #{access_token}", 
        "Content-type" => fmt,
        "X-SpeechContext" => speechContext
     } )
     
     request.body = audioData

    result = doHttpRequest(uri,request).body
    STDERR.puts "Result: #{result}"
    JSON.parse(result)
  end

##########################
# In App Messaging
##########################

  def postInAppMessage(token, addresses, subject, text)
    
    raise "Addresses are required" if addresses.nil? or !addresses.kind_of?(Array)
    raise "Subject or text required" if subject.nil? and text.nil?
    
    getAccessToken if @access_token == nil

    body = "{ 'Addresses':"
    body = body + "['" + addresses.join("','") + "']"
    body = body + ",'Text':'#{text}'" if !text.nil?
    body = body + ",'Subject': '#{subject}'" if !subject.nil?
    body = body + "}"

    uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/rest/1/MyMessages"})

    request = Net::HTTP::Post.new( uri.request_uri, 
      initheader = {'Accept' => 'application/json', 
        'Authorization' => "BEARER #{token}", 
        "Content-type" => 'application/json'
     } )

    request.body = body

    result = doHttpRequest(uri,request).body
    JSON.parse(result)
  end

  ##########################
  # SMS
  ##########################

    def sendSMS(addresses, message)
    
      raise "Addresses are required" if addresses.nil? or !addresses.kind_of?(Array) or addresses.length == 0
      raise "Message required" if message.nil? or message.empty?
    
      getAccessToken if @access_token == nil

      formatted_addresses = addresses.map { |a| a.start_with?("tel:") ? a : "tel:#{a}" }
      
      body = "{ 'outboundSMSRequest' :  { 'address':"
      if formatted_addresses.length == 1
        body = body + "'" + formatted_addresses[0] + "',"
      else
        body = body + "['" + formatted_addresses.join("','") + "'],"
      end
      body = body + "'message':'#{message}'"
      body = body + "}}"

      STDERR.puts "SendSMS: body=#{body.inspect}"
      
      uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/sms/v3/messaging/outbox"})

      request = Net::HTTP::Post.new( uri.request_uri, 
        initheader = {'Accept' => 'application/json', 
          'Authorization' => "BEARER #{@access_token}", 
          "Content-type" => 'application/json'
       } )

      request.body = body

      result = doHttpRequest(uri,request).body
      JSON.parse(result)
    end



##########################
# LOCATION
##########################

  def getLocation(code)

    raise "Location requires an Auth code tokens" if !validateString(code)

    uri = URI::HTTPS.build({:host => @endpoint_host, :path => "/2/devices/location"})

    request = Net::HTTP::Get.new( uri.request_uri, 
      initheader = {'Accept' => 'application/json', 'Authorization' => "BEARER #{code}"})

    JSON.parse(doHttpRequest(uri,request).body)
  end


##########################
# UTILS
##########################

      def doPost(path, payload, contentType, accept)

        uri = URI.parse("#{@endpoint_url}#{path}")

        request = Net::HTTP::Post.new( uri.request_uri, 
        initheader = {'Content-Type' => contentType, 
          'Accept' => accept,
          'client_id' => @client_id,
          'client_secret' => @client_secret
          }
        )

        request.body = payload

        doHttpRequest(uri,request).body
      end

      def doHttpRequest( uri, request )
        if( @proxy_url != nil )
          resp = Net::HTTP::Proxy(@proxy_url, @proxy_port).start(uri.host, 
          uri.port, 
          :use_ssl => true, 
          :verify_mode => OpenSSL::SSL::VERIFY_NONE ) do |http|
            http.request(request)
          end
        else
          resp = Net::HTTP.start(uri.host, 
          uri.port, 
          :use_ssl => true, 
          :verify_mode => OpenSSL::SSL::VERIFY_NONE ) do |http|
            http.request(request)
          end
        end
      end

      def validateString( s )
        s != nil and s.instance_of? String and s.length > 1
      end
    end
  end
