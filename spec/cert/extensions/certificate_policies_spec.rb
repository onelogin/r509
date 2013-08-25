require 'spec_helper'

include R509::Cert::Extensions

shared_examples_for "a correct R509 CertificatePolicies object" do
  before :all do
    klass = CertificatePolicies
    openssl_ext = OpenSSL::X509::Extension.new @policy_data
    @r509_ext = klass.new( openssl_ext )
  end

  it "should correctly parse the data" do
    @r509_ext.policies.count.should == 1
    @r509_ext.policies[0].policy_identifier.should == "2.16.840.1.12345.1.2.3.4.1"
    @r509_ext.policies[0].policy_qualifiers.cps_uris.should == ["http://example.com/cps", "http://other.com/cps"]
  end
end

describe R509::Cert::Extensions do
  include R509::Cert::Extensions

  context "CertificatePolicies" do
    before :all do
      @policy_data = "0\x81\x90\x06\x03U\x1D \x04\x81\x880\x81\x850\x81\x82\x06\v`\x86H\x01\xE09\x01\x02\x03\x04\x010s0\"\x06\b+\x06\x01\x05\x05\a\x02\x01\x16\x16http://example.com/cps0 \x06\b+\x06\x01\x05\x05\a\x02\x01\x16\x14http://other.com/cps0+\x06\b+\x06\x01\x05\x05\a\x02\x020\x1F0\x16\x16\x06my org0\f\x02\x01\x01\x02\x01\x02\x02\x01\x03\x02\x01\x04\x1A\x05thing"
    end

    context "creation & yaml generation" do
      context "one policy" do
        before :all do
          @args = {
            :critical => false,
            :value => [{ :policy_identifier => "2.16.840.1.12345.1.2.3.4.1",
              :cps_uris => ["http://example.com/cps","http://other.com/cps"],
              :user_notices => [ {:explicit_text => "thing", :organization => "my org", :notice_numbers => [1,2,3,4] }  ] }]
          }
          @cp = R509::Cert::Extensions::CertificatePolicies.new(@args)
        end

        it "creates extension" do
          @cp.should_not be_nil
          @cp.policies.count.should == 1
          @cp.policies[0].policy_identifier.should == "2.16.840.1.12345.1.2.3.4.1"
          @cp.policies[0].policy_qualifiers.cps_uris.should == ["http://example.com/cps", "http://other.com/cps"]
          @cp.policies[0].policy_qualifiers.user_notices.count.should == 1
          un = @cp.policies[0].policy_qualifiers.user_notices[0]
          un.notice_reference.notice_numbers.should == [1,2,3,4]
          un.notice_reference.organization.should == 'my org'
          un.explicit_text.should == "thing"
        end

        it "builds yaml" do
          YAML.load(@cp.to_yaml).should == @args
        end
      end

      context "multiple policies" do
        before :all do
          @args = {
            :critical => false,
            :value => [ {
              :policy_identifier => "2.16.840.1.99999.21.234",
              :cps_uris => ["http://example.com/cps","http://other.com/cps"],
              :user_notices => [ {:explicit_text => "this is a great thing", :organization => "my org", :notice_numbers => [1,2,3,4]} ]
            }, {
              :policy_identifier => "2.16.840.1.99999.21.235",
              :cps_uris => ["http://example.com/cps2"],
              :user_notices => [{:explicit_text => "this is a bad thing", :organization => "another org", :notice_numbers => [3,2,1] }, {:explicit_text => "another user notice"}]
            },
            {
              :policy_identifier => "2.16.840.1.99999.0"
            }]
          }
          @cp = R509::Cert::Extensions::CertificatePolicies.new(@args)
        end

        it "creates extension" do
          @cp.should_not be_nil
          @cp.policies.count.should == 3
          p0 = @cp.policies[0]
          p0.policy_identifier.should == "2.16.840.1.99999.21.234"
          p0.policy_qualifiers.cps_uris.should == ["http://example.com/cps", "http://other.com/cps"]
          p0.policy_qualifiers.user_notices.count.should == 1
          un0 = p0.policy_qualifiers.user_notices[0]
          un0.notice_reference.notice_numbers.should == [1,2,3,4]
          un0.notice_reference.organization.should == "my org"
          un0.explicit_text.should == "this is a great thing"
          p1 = @cp.policies[1]
          p1.policy_identifier.should == "2.16.840.1.99999.21.235"
          p1.policy_qualifiers.cps_uris.should == ["http://example.com/cps2"]
          p1.policy_qualifiers.user_notices.count.should == 2
          un1 = p1.policy_qualifiers.user_notices[0]
          un1.notice_reference.notice_numbers.should == [3,2,1]
          un1.notice_reference.organization.should == "another org"
          un1.explicit_text.should == 'this is a bad thing'
          un2 = p1.policy_qualifiers.user_notices[1]
          un2.notice_reference.should be_nil
          un2.explicit_text.should == "another user notice"
          p2 = @cp.policies[2]
          p2.policy_identifier.should == "2.16.840.1.99999.0"
          p2.policy_qualifiers.should be_nil
        end

        it "builds yaml" do
          YAML.load(@cp.to_yaml).should == @args
        end
      end

      context "default criticality" do
        before :all do
          @args = { :value => [{ :policy_identifier => "2.16.840.1.12345.1.2.3.4.1" }] }
          @cp = R509::Cert::Extensions::CertificatePolicies.new(@args)
        end

        it "creates extension" do
          @cp.critical?.should be_false
        end

        it "builds yaml" do
          YAML.load(@cp.to_yaml).should == @args.merge(:critical => false)
        end
      end

      context "non-default criticality" do
        before :all do
          @args = { :value => [{ :policy_identifier => "2.16.840.1.12345.1.2.3.4.1" }], :critical => true }
          @cp = R509::Cert::Extensions::CertificatePolicies.new(@args)
        end

        it "creates extension" do
          @cp.critical?.should be_true
        end

        it "builds yaml" do
          YAML.load(@cp.to_yaml).should == @args
        end
      end

    end

    it_should_behave_like "a correct R509 CertificatePolicies object"
  end

end
