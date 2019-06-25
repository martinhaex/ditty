# frozen_string_literal: true

libdir = File.expand_path(File.dirname(__FILE__) + '/lib')
$LOAD_PATH.unshift(libdir) unless $LOAD_PATH.include?(libdir)

require 'ditty/components/app'
Ditty.component :app

# Load more components here
