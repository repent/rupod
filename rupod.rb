#!/usr/bin/env ruby

require 'optparse'
require 'ostruct'
require 'pry'
require 'logger'
require 'awesome_print'

require 'rss'
require 'fileutils'

options = OpenStruct.new(
  verbose: false,
  dry: false,
)

#raise "$HOME not set" unless ENV['HOME']
options.home = ENV['HOME'] || '/home/slack'
options.rupod_dir = "#{options.home}/.rupod"
options.podcast_list =  "#{options.rupod_dir}/podcasts.txt",
options.podcast_dir = "#{options.home}/podcasts"
options.saved_podcasts = "#{options.rupod_dir}/saved.list"

log = Logger.new("#{options.rupod_dir}/rupod.log")
log.level = Logger::DEBUG

log.debug("Parsing options")

OptionParser.new do |opts|
  opts.banner = "Usage: #{$0} [options] file1 file1 file3 ..."
  
  opts.on('-h', '--help', 'Print this help') { puts opts; exit }
  opts.on('-v', '--verbose', 'Display verbose output') { options.verbose = true }
  opts.on('-d', '--dry-run', 'Make no changes, just display what would be done and exit') { options.dry = true }
  opts.on('-lLEVEL', '--log=LEVEL', 'Set log level (from debug, info, warn, error, fatal)') do |level|
    log.level = case level
      when 'debug', 4
        Logger::DEBUG
      when 'info', 3
        Logger::INFO
      when 'warn', 2
        Logger::WARN
      when 'error', 1
        Logger::ERROR
      when 'fatal', 0
        Logger::FATAL
      else
        raise 'Log level must be one of debug, info, warn, error, or fatal'
    end
  end
  opts.on('-LFILE', '--logfile=FILE', 'Log to FILE instead of standard error') { |f| log.reopen(f) }

  begin
    opts.parse!
  rescue OptionParser::ParseError => error
    # Without this rescue, Ruby would print the stack trace
    # of the error. Instead, we want to show the error message,
    # suggest -h or --help, and exit 1.
 
    $stderr.puts error
    $stderr.puts "(-h or --help will show valid options)"
    exit 1
  end
end

options.verbose = true if options.dry

log.debug("Started #{$0}")

# TODO: ENSURE ALL FILES AND FOLDERS ARE CREATED ALREADY

FileUtils.touch options.saved_podcasts unless File.exist? options.saved_podcasts
saved_podcasts = File.readlines(options.saved_podcasts).collect { |e| e.chomp }

File.foreach('/home/slack/.rupod/podcasts.txt') do |line|
  next unless line.chomp!.length > 0
  feed_url, title = line.split(' ', 2)
  rss = RSS::Parser.parse(feed_url, false)
  log.info "Feed type: #{rss.feed_type}"
  rss.items.each do |item|
    if saved_podcasts.include? item.link
      log.info "Skipping #{item.link}, it appears to be already downloaded (TODO: force instructions)"
      next
    end
    #binding.pry
    #title ||= /(.*)(\s+Episode\s+)\d+/
    dir = "#{options.podcast_dir}/#{title}"
    FileUtils.mkpath dir
    filename = "#{dir}/#{item.title}#{File.extname item.link}"
    # TODO: CHECK IF THIS FILE ALREADY EXISTS, DO SOMETHING SENSIBLE
    command = "wget #{item.link} -o '#{options.rupod_dir}/wget.log' -O '#{filename}'"
    log.info "Trying #{command}"
    if system(command)
      # Success
      log.info "#{item.title} recording complete (saved to #{filename})"
      puts "#{item.title} downloaded"
      `echo #{item.link} >> #{options.saved_podcasts}`
    else
      # Failure
      log.warn "#{item.title} recording failed!  Skipping..." # Retries?
    end
  end
end

log.debug("Finished #{$0} peacefully")
