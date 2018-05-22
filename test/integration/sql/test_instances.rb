require "helpers/integration_test_helper"
require "helpers/client_helper"
require "integration/sql/sql_instances_shared"

class TestFirstGenInstances < TestSqlInstancesShared
  def test_all
    test_name = some_instance_name
    instances = @client.instances.all
    assert_operator(instances.size, :>=, 1,
                    "expected at least one instance")

    filtered = instances.select { |i| i.name == test_name }
    assert_equal(1, filtered.size, "expected instance with name #{test_name}")
  end


  def test_ssl_certs
    list_result = @client.ssl_certs.all(some_instance_name)
    # initial Count
    cert_cnt = list_result.size
    assert_equal(0, cert_cnt, "new instance should have 0 initial ssl certs")

    # create new certs
    ssl_certs = (0..1).map do
      name = Fog::Mock.random_letters(16)
      create_resp = @client.insert_ssl_cert(some_instance_name, name)
      wait_until_complete { create_resp.operation }
      fingerprint = create_resp.client_cert.cert_info.sha1_fingerprint
      # verify it was created
      @client.ssl_certs.get(some_instance_name, fingerprint).tap do |result|
        assert_equal(name, result.common_name)
        assert_equal("sql#sslCert", result.kind)
      end
    end

    # check i1 was created
    list_result = @client.ssl_certs.all(some_instance_name)
    assert_equal(ssl_certs.size, list_result.size,
                 "expected #{ssl_certs.size} SSL certs")

    # delete one cert
    ssl_certs.first.destroy(:async => false)
    list_result = @client.ssl_certs.all(some_instance_name)
    assert_equal(ssl_certs.size - 1, list_result.size,
                 "expected one less SSL cert after deletion")

    # Reset SSL config
    instance = @client.instances.get(some_instance_name)
    instance.reset_ssl_config(:async => false)
    assert_equal(0, @client.ssl_certs.all(some_instance_name).size,
                 "expected no SSL certs after reset")
  end
end
