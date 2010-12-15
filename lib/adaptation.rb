require 'xmlsimple'
require 'yaml'
require 'active_record'
require 'active_record/base'
require 'adaptation/validateable'
require 'adaptation/message'
require 'adaptation/adaptor'
require 'adaptation/base'

ADAPTOR_ROOT = File.dirname(__FILE__) + '/..'

Adaptation::Initializer.run
