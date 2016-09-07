# module ActiveRecord
#   module ConnectionAdapters
#     module PostgreSQL
#       module Quoting
#
#         private
#         # ****** BEGIN PATCH ******
#         # when column of postgresql is an array, call super and fail. for example with [2] or ["2"].
#         # add condition for array elswhere call super
#         # @param [Value]
#         def _quote(value)
#           case value
#             when Array      then "'{#{value.join(',')}}'"
#             else
#               super
#           end
#         end
#       end
#     end
#   end
# end