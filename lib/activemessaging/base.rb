module ActiveMessaging
  ROOT     = File.expand_path(File.join(File.dirname(__FILE__), '..'))
  # Used to indicate that the processing for a thread shoud complete
  class StopProcessingException < Interrupt #:nodoc:
  end

  # Used to indicate that the processing on a message should cease,
  # and the message should be returned back to the broker as best it can be
  class AbortMessageException < Exception #:nodoc:
  end

  # Used to indicate that the processing on a message should cease,
  # but no further action is required
  class StopFilterException < Exception #:nodoc:
  end

  def ActiveMessaging.logger
    @@logger = nil unless defined? @@logger
    @@logger ||= Rails.logger if defined? Rails
    @@logger ||= ActiveRecord::Base.logger if defined? ActiveRecord
    @@logger ||= Logger.new(STDOUT)
    @@logger
  end

  # DEPRECATED, so I understand, but I'm using it nicely below.
  def self.load_extensions
    require 'logger'
    require 'activemessaging/support'
    require 'activemessaging/gateway'
    require 'activemessaging/adapter'
    require 'activemessaging/message_sender'
    require 'activemessaging/processor'
    require 'activemessaging/filter'
    require 'activemessaging/trace_filter'
    # load all under the adapters dir
    Dir[File.join(ROOT, 'activemessaging', 'adapters', '*.rb')].each do |a|
      begin
        adapter_name = File.basename(a, ".rb")
        require 'activemessaging/adapters/' + adapter_name
      rescue RuntimeError, LoadError => e
        logger.debug "ActiveMessaging: adapter #{adapter_name} not loaded: #{ e.message }"
      end
    end
  end

  def self.load_config
    path = File.expand_path("#{Rails.root}/config/messaging.rb")
    begin
      load path
    rescue MissingSourceFile
      logger.debug "ActiveMessaging: no '#{path}' file to load"
    rescue
      raise $!, " ActiveMessaging: problems trying to load '#{path}': \n\t#{$!.message}"
    end
  end

  def self.load_processors(first=true)
    #Load the parent processor.rb, then all child processor classes
    logger.debug "ActiveMessaging: Loading #{Rails.root + '/app/processors/application.rb'}" if first
    load "#{Rails.root}/app/processors/application_processor.rb" if File.exist?("#{Rails.root}/app/processors/application_processor.rb")
    Dir["#{Rails.root}/app/processors/*.rb"].each do |f|
      unless f.match(/\/application_processor.rb/)
        logger.debug "ActiveMessaging: Loading #{f}" if first
        load f
      end
    end
  end

  def self.reload_activemessaging
    # this is resetting the messaging.rb
    ActiveMessaging::Gateway.filters = []
    ActiveMessaging::Gateway.named_destinations = {}
    ActiveMessaging::Gateway.processor_groups = {}

    # now load the config
    load_config
    load_processors(false)
  end

  def self.load_activemessaging
    load_extensions
    load_config
    load_processors
  end

  def self.start
    if ActiveMessaging::Gateway.subscriptions.empty?
      err_msg = <<EOM
ActiveMessaging Error: No subscriptions.
If you have no processor classes in app/processors, add them using the command:
  script/generate processor DoSomething"

If you have processor classes, make sure they include in the class a call to 'subscribes_to':
  class DoSomethingProcessor < ActiveMessaging::Processor
    subscribes_to :do_something
EOM
      puts err_msg
      logger.error err_msg
      exit
    end
    Gateway.start
  end
end