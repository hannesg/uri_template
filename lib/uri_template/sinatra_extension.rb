# -*- encoding : utf-8 -*-
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the Affero GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#    (c) 2011 - 2012 by Hannes Georg
#

require 'uri_template'
module URITemplate
module SinatraExtension

  def self.registered(base)
    base.register(Routing)
  end

  module Routing

    def self.registered(base)
      base.send(:include, ClassMethods)
    end

    module ClassMethods
    private

      def process_route(pattern, keys, conditions, block = nil, values = [])
        if pattern.kind_of? ::URITemplate
          begin
            route = @request.fullpath
            route = '/' if route.empty? and not settings.empty_path_info?

            ex = pattern.extract(route)
            return unless ex

            keys[values.length..-1].each do |key|
              values << ex[key]
            end

            original, @params = params, params.merge(ex)
            @params['captures'] = values
            @params['splat'] = []

            catch(:pass) do
              conditions.each { |c| throw :pass if c.bind(self).call == false }
              block ? block[self, values] : yield(self, values)
            end
          ensure
            @params = original if original
          end
        else
          super
        end
      end
    end

  end

end
end

