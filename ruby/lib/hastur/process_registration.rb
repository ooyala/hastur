reg_data = {}

Hastur::RegistrationData.each do |data|
  case data
  when Hash
    reg_data = reg_data.merge(data)
  else
    raise "Invalid registration data #{data.inspect} in Hastur!"
  end
end

Hastur.register_process Hastur.app_name, reg_data
