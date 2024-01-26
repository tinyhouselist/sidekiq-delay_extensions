# frozen_string_literal: true

require_relative "helper"
require "sidekiq/api"
require "active_record"
require "action_mailer"
Sidekiq::DelayExtensions.enable_delay!

class MyModel < ActiveRecord::Base
  def self.long_class_method
    raise "Should not be called!"
  end
end

class UserMailer < ActionMailer::Base
  def greetings(a, b)
    raise "Should not be called!"
  end
end

class SomeClass
  def self.doit(arg)
  end
end

module SomeModule
  def self.doit(arg)
  end
end

describe Sidekiq::DelayExtensions do
  before do
    @cfg = reset!
  end

  it "allows delayed execution of ActiveRecord class methods" do
    assert_equal [], Sidekiq::Queue.all.map(&:name)
    q = Sidekiq::Queue.new
    assert_equal 0, q.size
    MyModel.delay.long_class_method
    assert_equal ["default"], Sidekiq::Queue.all.map(&:name)
    assert_equal 1, q.size
  end

  it "uses and stringifies specified options" do
    assert_equal [], Sidekiq::Queue.all.map(&:name)
    q = Sidekiq::Queue.new("notdefault")
    assert_equal 0, q.size
    MyModel.delay(queue: :notdefault).long_class_method
    assert_equal ["notdefault"], Sidekiq::Queue.all.map(&:name)
    assert_equal ["MyModel.long_class_method"], q.map(&:display_class)
    assert_equal 1, q.size
  end

  it "allows delayed scheduling of AR class methods" do
    ss = Sidekiq::ScheduledSet.new
    assert_equal 0, ss.size
    MyModel.delay_for(5.days).long_class_method
    assert_equal 1, ss.size
  end

  it "allows until delayed scheduling of AR class methods" do
    ss = Sidekiq::ScheduledSet.new
    assert_equal 0, ss.size
    MyModel.delay_until(1.day.from_now).long_class_method
    assert_equal 1, ss.size
  end

  it "allows delayed delivery of ActionMailer mails" do
    assert_equal [], Sidekiq::Queue.all.map(&:name)
    q = Sidekiq::Queue.new
    assert_equal 0, q.size
    UserMailer.delay.greetings(1, 2)
    assert_equal ["default"], Sidekiq::Queue.all.map(&:name)
    assert_equal 1, q.size
  end

  it "allows delayed scheduling of AM mails" do
    ss = Sidekiq::ScheduledSet.new
    assert_equal 0, ss.size
    UserMailer.delay_for(5.days).greetings(1, 2)
    assert_equal 1, ss.size
  end

  it "allows until delay scheduling of AM mails" do
    ss = Sidekiq::ScheduledSet.new
    assert_equal 0, ss.size
    UserMailer.delay_until(5.days.from_now).greetings(1, 2)
    assert_equal 1, ss.size
  end

  it "allows delay of any ole class method" do
    q = Sidekiq::Queue.new
    assert_equal 0, q.size
    SomeClass.delay.doit(Date.today)
    assert_equal 1, q.size
  end

  it "logs large payloads" do
    output = capture_logging(@cfg, Logger::WARN) do
      SomeClass.delay.doit("a" * 8192)
    end
    assert_match(/#{SomeClass}.doit job argument is/o, output)
  end

  it "allows delay of any module class method" do
    q = Sidekiq::Queue.new
    assert_equal 0, q.size
    SomeModule.delay.doit(Date.today)
    assert_equal 1, q.size
  end
end
