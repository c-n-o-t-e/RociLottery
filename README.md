# RociLottery

Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

Install Foundry
cargo install --git https://github.com/gakonst/foundry --bin forge

Run  `git submodule init`

Run `git submodule update`

Run `forge build` to compile contracts

Run `forge test -vvvv -f https://kovan.infura.io/v3/your_infura_id ` to run test via kovan testnet
