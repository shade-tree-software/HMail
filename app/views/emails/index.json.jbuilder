json.array!(@emails) do |email|
  json.extract! email, :id, :body, :user_id
  json.url email_url(email, format: :json)
end
