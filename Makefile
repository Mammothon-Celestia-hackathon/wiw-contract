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


show-debate-store:
	@echo "show debate store ... "
	@curl -s https://aptos.testnet.bardock.movementlabs.xyz/v1/accounts/0xd7ae4e1e8d4486450936d8fdbb93af0cba8e1ae00c00f82653f76c5d65d76a6f/resource/0xd7ae4e1e8d4486450936d8fdbb93af0cba8e1ae00c00f82653f76c5d65d76a6f::ai_debate::DebateStore | jq .

# public entry fun create_debate(
#     creator: &signer,
#     topic: String,
#     ai_a: String,
#     ai_b: String,
#     duration: u64
# ) acquires DebateStore {
create-debate:
	@echo "create debate call on contract"
	@movement move run \
		--profile jeongseup \
		--function-id 'jeongseup::ai_debate::create_debate' \
  		--args \
        	String:"topic_name" \
        	String:"0xd7ae4e1e8d4486450936d8fdbb93af0cba8e1ae00c00f82653f76c5d65d76a6f" \
			String:"0x123" \
			u64:3600