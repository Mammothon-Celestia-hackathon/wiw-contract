compile:
	@echo "compile...."
	@movement move compile

test:
	@echo "unit testing...."
	@movement move test

publish:
	@echo "publish move contract...."
	@movement move publish

dev-compile:
	@echo "after clean cache, compile move contract in dev mode..."
	@movement move clean --assume-yes
	@movement move compile --dev --named-addresses debate=jeongseup
	@movement move publish --dev --named-addresses debate=jeongseup 

dev-publish:
	@echo "publish move contract in dev mode..."
	@movement move publish --dev --named-addresses debate=jeongseup --profile jeongseup --assume-yes

get-message:
	@echo "get contract message by interaction move contract...."
	@movement move view \
		--function-id 'default::message::get_message' \
		--args 'address:0xd7ae4e1e8d4486450936d8fdbb93af0cba8e1ae00c00f82653f76c5d65d76a6f'

set-message:
	@echo "set contract message by interaction move contract...."
	@movement move run \
		--function-id 'default::message::set_message' \
  		--args 'string:hello, Jeongseup'

