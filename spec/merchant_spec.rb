require 'spec_helper'
require 'stringio'

RSpec.describe ApplePayMerchant do
  # Helper to stub module-level functions by stubbing the file operations they use
  def stub_load_merchant_identity_certificates
    mock_cert = double('cert', to_pem: 'cert_pem')
    mock_key = double('key')
    
    # Stub file operations that load_merchant_identity_certificates uses
    cert_content = "-----BEGIN CERTIFICATE-----\nMOCK_CERT\n-----END CERTIFICATE-----"
    key_content = "-----BEGIN PRIVATE KEY-----\nMOCK_KEY\n-----END PRIVATE KEY-----"
    
    # Allow File.read to handle multiple files
    allow(File).to receive(:read).and_call_original
    allow(File).to receive(:read).with('merchant_identity.pem').and_return(cert_content)
    allow(File).to receive(:read).with('payment_processing.key').and_return('test_key')
    
    # Allow File.open for both the key file and other files (like static assets)
    key_io = StringIO.new(key_content)
    allow(File).to receive(:open).and_call_original
    allow(File).to receive(:open).with('merchant_identity.key').and_return(key_io)
    allow(OpenSSL::X509::Certificate).to receive(:new).with(cert_content).and_return(mock_cert)
    allow(OpenSSL::PKey).to receive(:read).and_return(mock_key)
    
    [mock_cert, mock_key]
  end

  def stub_read_configuration(config = nil)
    config ||= {
      'merchantIdentifier' => 'merchant.test',
      'initiativeContext' => 'example.com',
      'displayName' => 'Test Merchant'
    }
    allow(File).to receive(:read).with('config.json').and_return(config.to_json)
    config
  end

  describe 'GET /' do
    it 'redirects to /index.html' do
      stub_load_merchant_identity_certificates
      get '/'
      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('/index.html')
    end
  end

  describe 'POST /validatemerchant' do
    let(:valid_validation_url) { 'https://apple-pay-gateway.apple.com/pay' }
    let(:invalid_validation_url) { 'https://evil.com/validate' }

    before do
      stub_load_merchant_identity_certificates
      stub_read_configuration
    end

    context 'with invalid validation URL' do
      it 'returns 400 for non-Apple domain' do
        post '/validatemerchant', { 'validationURL' => invalid_validation_url }
        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Invalid validation_url')
      end
    end

    context 'with valid validation URL' do
      let(:mock_response) do
        double('response', is_a?: true, code: '200', body: '{"session": "test"}')
      end
      let(:mock_http) { double('http') }

      before do
        # Mock the HTTP request to Apple
        allow(Net::HTTP).to receive(:new).and_return(mock_http)
        allow(mock_http).to receive(:use_ssl=)
        allow(mock_http).to receive(:ssl_timeout=)
        allow(mock_http).to receive(:read_timeout=)
        allow(mock_http).to receive(:open_timeout=)
        allow(mock_http).to receive(:cert=)
        allow(mock_http).to receive(:key=)
        allow(mock_http).to receive(:ssl_version=)
        allow(mock_http).to receive(:verify_mode=)
        allow(mock_http).to receive(:request).and_return(mock_response)
        allow(mock_response).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      end

      it 'validates the URL pattern and processes request' do
        post '/validatemerchant', { 'validationURL' => valid_validation_url }
        # Should not return 400 for valid URL
        expect(last_response.status).not_to eq(400)
      end
    end

    context 'with missing configuration' do
      before do
        allow(Object).to receive(:read_configuration).and_raise('Configuration missing keys')
      end

      it 'handles configuration errors gracefully' do
        post '/validatemerchant', { 'validationURL' => valid_validation_url }
        expect(last_response.status).to eq(500)
      end
    end
  end

  describe 'POST /completesession' do
    let(:payment_token) do
      {
        'token' => {
          'paymentData' => {
            'version' => 'EC_v1',
            'data' => 'test_data',
            'signature' => 'test_signature',
            'header' => {
              'ephemeralPublicKey' => 'test_key',
              'publicKeyHash' => 'test_hash',
              'transactionId' => 'test_id'
            }
          }
        }
      }
    end

    before do
      stub_load_merchant_identity_certificates

      # Mock Pedicel - create a mock that returns a symmetric key
      mock_pedicel = double('pedicel')
      allow(mock_pedicel).to receive(:symmetric_key).and_return(['test_key'].pack('H*'))
      allow(Pedicel::EC).to receive(:new).and_return(mock_pedicel)
    end

    it 'accepts payment token and returns 200' do
      post '/completesession', payment_token.to_json, { 'CONTENT_TYPE' => 'application/json' }
      expect(last_response.status).to eq(200)
    end

    it 'handles invalid JSON gracefully' do
      # Roda's json_parser plugin will raise JSON::ParserError for invalid JSON
      # This will result in a 500 error or the error being handled by Roda
      expect {
        post '/completesession', 'invalid json', { 'CONTENT_TYPE' => 'application/json' }
      }.to raise_error(JSON::ParserError)
    end
  end

  describe 'static file serving' do
    before do
      stub_load_merchant_identity_certificates
    end

    it 'serves files from public directory' do
      get '/index.html'
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Apple Pay')
    end
  end
end
