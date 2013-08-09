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

# A module which all literal tokens should include.
module URITemplate::Literal

  include URITemplate::Token

  SLASH = ?/

  attr_reader :string

  def literal?
    true
  end

  def expression?
    false
  end

  def size
    0
  end

  def expand(_)
    return string
  end

  def expand_partial(_)
    return [self]
  end

  def starts_with_slash?
    string[0] == SLASH
  end

  def ends_with_slash?
    string[-1] == SLASH
  end

  alias to_s string

end
