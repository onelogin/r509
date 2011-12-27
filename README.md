#r509 [![Build Status](https://secure.travis-ci.org/reaperhulk/r509.png)](http://travis-ci.org/reaperhulk/r509)
r509 is a wrapper for various OpenSSL functions to allow easy creation of CSRs, signing of certificates, and revocation via CRL.

##Requirements/Installation

r509 requires the Ruby OpenSSL bindings as well as yaml support (present by default in modern Ruby builds).
To install the gem: ```gem install r509-(version).gem```

##Running Tests/Building Gem
If you want to run the tests for r509 you'll need rspec. Additionally, you may want to install rcov/simplecov (ruby 1.8/1.9 respectively) and yard for running the code coverage and documentation tasks in the Rakefile. ```rake -T``` for a complete list of rake tasks available.

##Continuous Integration
We run continuous integration tests (using Travis-CI) against 1.8.7, 1.9.2, 1.9.3, ree, and ruby-head.

##Executable

Inside the gem there is a bin directory that contains ```r509```. You can use this in interactive mode to generate a CSR and (optionally) self-sign it.

##Usage
###CSR
To generate a 2048-bit RSA CSR

```ruby
csr = R509::Csr.new(
    :subject => [
        ['CN','somedomain.com'],
        ['O','My Org'],
        ['L','City'],
        ['ST','State'],
        ['C','US']
    ]
)
```

To load an existing CSR (without private key)

```ruby
csr_pem = File.read("/path/to/csr")
csr = R509::Csr.new(:csr => csr_pem)
```

To create a new CSR from the subject of a certificate

```ruby
cert_pem = File.read("/path/to/cert")
csr = R509::Csr.new(:cert => cert_pem)
```

To create a CSR with SAN names

```ruby
csr = R509::Csr.new(
    :subject => [['CN','something.com']],
    :san_names => ["something2.com","something3.com"]
)
```

###Cert
To load an existing certificate

```ruby
cert_pem = File.read("/path/to/cert")
R509::Cert.new(:cert => cert_pem)
```

Load a cert and key

```ruby
cert_pem = File.read("/path/to/cert")
key_pem = File.read("/path/to/key")
R509::Cert.new(
    :cert => cert_pem,
    :key => key_pem
)
```

Load an encrypted private key

```ruby
cert_pem = File.read("/path/to/cert")
key_pem = File.read("/path/to/key")
R509::Cert.new(
    :cert => cert_pem,
    :key => key_pem,
    :password => "private_key_password"
)
```

###Self-Signed Certificate
To create a self-signed certificate

```ruby
not_before = Time.now.to_i
not_after = Time.now.to_i+3600*24*7300
csr = R509::Csr.new(
    :subject => [['C','US'],['O','r509 LLC'],['CN','r509 Self-Signed CA Test']]
)
ca = R509::CertificateAuthority::Signer.new
cert = ca.selfsign(
    :csr => csr,
    :not_before => not_before,
    :not_after => not_after
)
```

###Config

Create a basic CaConfig object

```ruby
cert_pem = File.read("/path/to/cert")
key_pem = File.read("/path/to/key")
cert = R509::Cert.new(
    :cert => cert_pem,
    :key => key_pem
)
config = R509::Config::CaConfig.new(
    :ca_cert => cert
)
```

Add a signing profile named "server" (CaProfile) to a config object

```ruby
profile = R509::Config::CaProfile.new(
    :basic_constraints => "CA:FALSE",
    :key_usage => ["digitalSignature","keyEncipherment"],
    :extended_key_usage => ["serverAuth"],
    :certificate_policies => ["policyIdentifier=2.16.840.1.999999999.1.2.3.4.1", "CPS.1=http://example.com/cps"],
    :subject_item_policy => nil
)
#config object from above assumed
config.set_profile("server",profile)
```

Set up a subject item policy (required/optional). The keys must match OpenSSL's shortnames!

```ruby
profile = R509::Config::CaProfile.new(
    :basic_constraints => "CA:FALSE",
    :key_usage => ["digitalSignature","keyEncipherment"],
    :extended_key_usage => ["serverAuth"],
    :certificate_policies => ["policyIdentifier=2.16.840.1.999999999.1.2.3.4.1", "CPS.1=http://example.com/cps"],
    :subject_item_policy => {
        "CN" => "required",
        "O" => "optional"
    }
)
#config object from above assumed
config.set_profile("server",profile)
```

Load CaConfig + Profile from YAML

```ruby
config = R509::Config::CaConfig.from_yaml("test_ca", "config_test.yaml")
```

Example YAML (more options are supported than this example)

```yaml
test_ca: {
    ca_cert: {
        cert: '/path/to/test_ca.cer',
        key: '/path/to/test_ca.key'
    },
    crl_list: "crl_list_file.txt",
    crl_number: "crl_number_file.txt",
    cdp_location: 'URI:http://crl.domain.com/test_ca.crl',
    crl_validity_hours: 168, #7 days
    ocsp_location: 'URI:http://ocsp.domain.com',
    message_digest: 'SHA1', #SHA1, SHA256, SHA512 supported. MD5 too, but you really shouldn't use that unless you have a good reason
    profiles: {
        server: {
            basic_constraints: "CA:FALSE",
            key_usage: [digitalSignature,keyEncipherment],
            extended_key_usage: [serverAuth],
            certificate_policies: [ "policyIdentifier=2.16.840.1.9999999999.1.2.3.4.1", "CPS.1=http://example.com/cps"],
            subject_item_policy: {
                "CN" : "required",
                "O" : "optional",
                "ST" : "required",
                "C" : "required",
                "OU" : "optional" }
        }
    }
}
```

Load Muliple CaConfigs Using a CaConfigPool

```ruby
pool = R509::Config::CaConfigPool.from_yaml("certificate_authorities", "config_pool.yaml")
```

Example (Minimal) Config Pool YAML

```yaml
certificate_authorities: {
    test_ca: {
        ca_cert: {
            cert: 'test_ca.cer',
            key: 'test_ca.key'
        }
    },
    second_ca: {
        ca_cert: {
            cert: 'second_ca.cer',
            key: 'second_ca.key'
        }
    }
}
```

###CertificateAuthority

Sign a CSR

```ruby
csr = R509::Csr.new(
    :subject => [
        ['CN','somedomain.com'],
        ['O','My Org'],
        ['L','City'],
        ['ST','State'],
        ['C','US']
    ]
)
#assume config from yaml load above
ca = R509::CertificateAuthority::Signer.new(config)
cert = ca.sign_cert(
    :profile_name => "server",
    :csr => csr
)
```

Override a CSR's subject or SAN names when signing

```ruby
csr = R509::Csr.new(
    :subject => [
        ['CN','somedomain.com'],
        ['O','My Org'],
        ['L','City'],
        ['ST','State'],
        ['C','US']
    ]
)
data_hash = csr.to_hash
data_hash[:san_names] = ["sannames.com","domain2.com"]
data_hash[:subject]["CN"] = "newdomain.com"
data_hash[:subejct]["O"] = "Org 2.0"
#assume config from yaml load above
ca = R509::CertificateAuthority::Signer.new(config)
cert = ca.sign_cert(
    :profile_name => "server",
    :csr => csr,
    :data_hash => data_hash
)
```

###Load Hardware Engines

The engine you want to load must already be available to OpenSSL. How to compile/install OpenSSL engines is outside the scope of this document.

```ruby
OpenSSL::Engine.load("engine_name")
engine = OpenSSL::Engine.by_id("engine_name")
key = R509::PrivateKey(
    :engine => engine,
    :key_name => "my_key_name"
)
```

You can then use this key for signing.

##Documentation

There is (relatively) complete documentation available for every method and class in r509 available via yardoc. If you installed via gem it should be pre-generated in the doc directory. If you cloned this repo, just type "rake yard" with the yard gem installed.

##Thanks to...
* [Sean Schulte](https://github.com/sirsean)
* [Mike Ryan](https://github.com/justfalter)

##License
See the LICENSE file. Licensed under the Apache 2.0 License
