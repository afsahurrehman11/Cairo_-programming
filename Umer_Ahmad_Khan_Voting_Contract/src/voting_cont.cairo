#[starknet::contract]
mod VotingContract {
	use starknet::ContractAddress;
	use starknet::get_caller_address;
	use starknet::storage::{
		Map, StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
		StoragePointerWriteAccess,
	};

	#[storage]
	struct Storage {
		owner: ContractAddress,
		question: felt252,
		yes_votes: u128,
		no_votes: u128,
		is_open: bool,
		has_voted: Map<ContractAddress, bool>,
	}

	#[event]
	#[derive(Drop, starknet::Event)]
	enum Event {
		VoteCast: VoteCast,
		VotingClosed: VotingClosed,
	}

	#[derive(Drop, starknet::Event)]
	struct VoteCast {
		voter: ContractAddress,
		support: bool,
	}

	#[derive(Drop, starknet::Event)]
	struct VotingClosed {
		closed_by: ContractAddress,
	}

	#[constructor]
	fn constructor(ref self: ContractState, question: felt252) {
		self.owner.write(get_caller_address());
		self.question.write(question);
		self.is_open.write(true);
	}

	#[external(v0)]
	fn vote(ref self: ContractState, support: bool) {
		let caller = get_caller_address();
		assert(self.is_open.read(), 'Voting is closed');
		assert(!self.has_voted.read(caller), 'Already voted');

		self.has_voted.write(caller, true);

		if support {
			self.yes_votes.write(self.yes_votes.read() + 1_u128);
		} else {
			self.no_votes.write(self.no_votes.read() + 1_u128);
		}

		self.emit(Event::VoteCast(VoteCast { voter: caller, support }));
	}

	#[external(v0)]
	fn close_voting(ref self: ContractState) {
		let caller = get_caller_address();
		assert(caller == self.owner.read(), 'Only owner can close voting');
		assert(self.is_open.read(), 'Voting already closed');

		self.is_open.write(false);
		self.emit(Event::VotingClosed(VotingClosed { closed_by: caller }));
	}

	#[external(v0)]
	fn get_question(self: @ContractState) -> felt252 {
		self.question.read()
	}

	#[external(v0)]
	fn get_owner(self: @ContractState) -> ContractAddress {
		self.owner.read()
	}

	#[external(v0)]
	fn is_voting_open(self: @ContractState) -> bool {
		self.is_open.read()
	}

	#[external(v0)]
	fn get_results(self: @ContractState) -> (u128, u128) {
		(self.yes_votes.read(), self.no_votes.read())
	}

	#[external(v0)]
	fn has_address_voted(self: @ContractState, voter: ContractAddress) -> bool {
		self.has_voted.read(voter)
	}
}
