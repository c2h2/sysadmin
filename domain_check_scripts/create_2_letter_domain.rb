
all_2_letter_com = (('a'..'z').to_a + ('0'..'9').to_a).repeated_permutation(2).first(36**2).map{|i| i*""+".com"}
all_2_letter_cc = (('a'..'z').to_a + ('0'..'9').to_a).repeated_permutation(2).first(36**2).map{|i| i*""+".cc"}
all_2_letter_io = (('a'..'z').to_a + ('0'..'9').to_a).repeated_permutation(2).first(36**2).map{|i| i*""+".io"}

puts all_2_letter_cc
