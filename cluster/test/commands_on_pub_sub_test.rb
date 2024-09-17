# frozen_string_literal: true

require "helper"

# ruby -w -Itest test/cluster_commands_on_pub_sub_test.rb
# @see https://redis.io/commands#pubsub
class TestClusterCommandsOnPubSub < Minitest::Test
  include Helper::Cluster

  def test_publish_subscribe_unsubscribe_pubsub
    sub_cnt = 0
    messages = {}

    thread = Thread.new do
      redis.subscribe('channel1', 'channel2') do |on|
        on.subscribe { sub_cnt += 1 }
        on.message do |c, msg|
          messages[c] = msg
          redis.unsubscribe if messages.size == 2
        end
      end
    end

    Thread.pass until sub_cnt == 2

    publisher = build_another_client

    assert_equal %w[channel1 channel2], publisher.pubsub(:channels, 'channel*')
    assert_equal({ 'channel1' => 1, 'channel2' => 1, 'channel3' => 0 },
                 publisher.pubsub(:numsub, 'channel1', 'channel2', 'channel3'))

    publisher.publish('channel1', 'one')
    publisher.publish('channel2', 'two')
    publisher.publish('channel3', 'three')

    thread.join

    assert_equal(2, messages.size)
    assert_equal('one', messages['channel1'])
    assert_equal('two', messages['channel2'])
  end

  def test_publish_psubscribe_punsubscribe_pubsub
    sub_cnt = 0
    messages = {}

    thread = Thread.new do
      redis.psubscribe('guc*', 'her*') do |on|
        on.psubscribe { sub_cnt += 1 }
        on.pmessage do |_ptn, c, msg|
          messages[c] = msg
          redis.punsubscribe if messages.size == 2
        end
      end
    end

    Thread.pass until sub_cnt == 2

    publisher = build_another_client

    assert_equal 2, publisher.pubsub(:numpat)

    publisher.publish('burberry1', 'one')
    publisher.publish('gucci2', 'two')
    publisher.publish('hermes3', 'three')

    thread.join

    assert_equal(2, messages.size)
    assert_equal('two', messages['gucci2'])
    assert_equal('three', messages['hermes3'])
  end

  def test_spublish_ssubscribe_sunsubscribe_pubsub
    omit_version('7.0.0')

    sub_cnt = 0
    messages = {}

    thread = Thread.new do
      redis.ssubscribe('channel1', 'channel2') do |on|
        on.ssubscribe { sub_cnt += 1 }
        on.smessage do |c, msg|
          messages[c] = msg
          redis.sunsubscribe if messages.size == 2
        end
      end
    end

    Thread.pass until sub_cnt == 2

    publisher = build_another_client

    assert_equal %w[channel1 channel2], publisher.pubsub(:shardchannels, 'channel*')
    assert_equal({ 'channel1' => 1, 'channel2' => 1, 'channel3' => 0 },
                 publisher.pubsub(:shardnumsub, 'channel1', 'channel2', 'channel3'))

    publisher.spublish('channel1', 'one')
    publisher.spublish('channel2', 'two')
    publisher.spublish('channel3', 'three')

    thread.join

    assert_equal(2, messages.size)
    assert_equal('one', messages['channel1'])
    assert_equal('two', messages['channel2'])
  end

  def test_spublish_ssubscribe_sunsubscribe_pubsub
    sub_cnt = 0
    messages = {}

    thread = Thread.new do
      redis.ssubscribe('{channel}1', '{channel}2') do |on|
        on.ssubscribe { |_c, t| sub_cnt = t }
        on.sunsubscribe { |_c, t| sub_cnt = t }
        on.smessage do |chn, msg|
          messages[chn] = msg
          # FIXME: blocking occurs when `unsubscribe` method was called with channel arguments
          redis.sunsubscribe if messages.size == 2
        end
      end
    end

    Thread.pass until sub_cnt == 2

    publisher = build_another_client

    assert_equal [], publisher.pubsub(:channels)
    assert_equal [], publisher.pubsub(:channels, '{channel}1')
    assert_equal [], publisher.pubsub(:channels, '{channel}2')
    assert_equal [], publisher.pubsub(:channels, '{channel}3')
    assert_equal({}, publisher.pubsub(:numsub))
    assert_equal({ '{channel}1' => 0, '{channel}2' => 0, '{channel}3' => 0 },
                 publisher.pubsub(:numsub, '{channel}1', '{channel}2', '{channel}3'))

    publisher.spublish('{channel}1', 'one')
    publisher.spublish('{channel}2', 'two')
    publisher.spublish('{channel}3', 'three')

    thread.join

    assert_equal({ '{channel}1' => 'one', '{channel}2' => 'two' }, messages.sort.to_h)

    assert_equal [], publisher.pubsub(:channels)
    assert_equal [], publisher.pubsub(:channels, '{channel}1')
    assert_equal [], publisher.pubsub(:channels, '{channel}2')
    assert_equal [], publisher.pubsub(:channels, '{channel}3')
    assert_equal({}, publisher.pubsub(:numsub))
    assert_equal({ '{channel}1' => 0, '{channel}2' => 0, '{channel}3' => 0 },
                 publisher.pubsub(:numsub, '{channel}1', '{channel}2', '{channel}3'))
  end
end
