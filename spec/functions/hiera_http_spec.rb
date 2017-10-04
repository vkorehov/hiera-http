require 'spec_helper'
  
require 'puppet/functions/hiera_http'

describe FakeFunction do

  let(:function) { described_class.new }
  before(:each) do
    @lookuphttp = instance_double("LookupHttp")
    @context = instance_double("Puppet::LookupContext")
    allow(LookupHttp).to receive(:new).and_return(@lookuphttp)
    allow(@context).to receive(:cache_has_key)
    allow(@context).to receive(:explain)
    allow(@context).to receive(:interpolate)
    allow(@context).to receive(:cache)
    allow(@context).to receive(:not_found)
    allow(@context).to receive(:interpolate).with('/path').and_return('/path')
  end

  describe "#lookup_key" do

    context "Should run" do
      let(:options) { {
        'uri' => 'http://192.168.0.1:8080/path'
      } }

      it "should run" do
        expect(LookupHttp).to receive(:new).with({ :host => '192.168.0.1', :port => 8080 })
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('value')
        expect(function.lookup_key('bar', options, @context)).to eq('value')
      end
    end

    context "When using __XXX__ interpolation" do
      let(:key) { 'foo::bar::tango' }
       
      it "should interpolate __KEY__ correctly" do
        options = { 'uri' => 'http://localhost/path/__KEY__' }
        expect(@context).to receive(:interpolate).with('/path/foo::bar::tango').and_return('/path/foo::bar::tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo::bar::tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __MODULE__ correctly" do
        options = { 'uri' => 'http://localhost/path/__MODULE__' }
        expect(@context).to receive(:interpolate).with('/path/foo').and_return('/path/foo')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __CLASS__ correctly" do
        options = { 'uri' => 'http://localhost/path/__CLASS__' }
        expect(@context).to receive(:interpolate).with('/path/foo::bar').and_return('/path/foo::bar')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo::bar')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate __PARAMETER__ correctly" do
        options = { 'uri' => 'http://localhost/path/__PARAMETER__' }
        expect(@context).to receive(:interpolate).with('/path/tango').and_return('/path/tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end

      it "should interpolate more than one field" do
        options = { 'uri' => 'http://localhost/path/__MODULE__/__PARAMETER__/__PARAMETER__' }
        expect(@context).to receive(:interpolate).with('/path/foo/tango/tango').and_return('/path/foo/tango/tango')
        expect(@lookuphttp).to receive(:get_parsed).with('/path/foo/tango/tango')
        function.lookup_key('foo::bar::tango', options, @context)
      end


    end

    context "When confine_to_keys is set" do
      let(:options) { {
        'uri' => 'http://localhost/path',
        'confine_to_keys' => [ /^tango.*/ ],
      } }

      before(:each) do
        allow(@context).to receive(:interpolate).with('/path').and_return('/path')
      end

      it "should return not found for non matching keys" do
        expect(@context).to receive(:not_found)
        expect(@lookuphttp).not_to receive(:get_parsed)
        function.lookup_key('bar', options, @context)
      end

      it "should run if key matches" do
        expect(@context).not_to receive(:not_found)
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('value')
        expect(function.lookup_key('tangodelta', options, @context)).to eq('value')
      end
    end

    context "Output of lookup_http" do
      let(:options) { {
        'uri' => 'http://localhost/path',
      } }
      it "should dig if the value is a hash" do
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return({ 'tango' => 'delta' })
        expect(function.lookup_key('tango', options, @context)).to eq('delta')
      end
      it "should return the whole value if the value is a string" do
        expect(@lookuphttp).to receive(:get_parsed).with('/path').and_return('delta')
        expect(function.lookup_key('tango', options, @context)).to eq('delta')
      end
    end

    context "cached values" do
      let(:options) { {
        'uri' => 'http://localhost/path'
      } }

      it "should used cached value when available" do
        expect(@context).to receive(:cache_has_key).with('/path').and_return(true)
        expect(@context).to receive(:cached_value).with('/path').and_return({ 'tango' => 'bar'})
        expect(@lookuphttp).not_to receive(:get_parsed)
        expect(function.lookup_key('tango', options, @context)).to eq('bar')
      end
    end
  end
end
