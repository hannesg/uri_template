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

# This should make it possible to do basic analysis independently from the concrete type.
# Usually the submodules {URITemplate::Literal} and {URITemplate::Expression} are used.
#
# @abstract
module URITemplate::Token

  EMPTY_ARRAY = [].freeze

  # The variable names used in this token.
  #
  # @return [Array<String>]
  def variables
    EMPTY_ARRAY
  end

  # Number of variables in this token
  def size
    variables.size
  end

  def starts_with_slash?
    false
  end

  def ends_with_slash?
    false
  end

  def scheme?
    false
  end

  def host?
    false
  end

  # @abstract
  def expand(variables)
    raise "Please implement #expand(variables) on #{self.class.inspect}."
  end

  # @abstract
  def to_s
    raise "Please implement #to_s on #{self.class.inspect}."
  end

end