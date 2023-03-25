# Smart Contract Infrastructure [![Open in Gitpod][gitpod-badge]][gitpod] [![Foundry][foundry-badge]][foundry] [![License: MIT][license-badge]][license]

[gitpod]: https://gitpod.io/#https://github.com/Insure-a-Bag/Smart-Contract-
[gitpod-badge]: https://img.shields.io/badge/Gitpod-Open%20in%20Gitpod-FFB45B?logo=gitpod
[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg
[license]: https://opensource.org/licenses/MIT
[license-badge]: https://img.shields.io/badge/License-MIT-blue.svg

## About Us

The following repository contains the Insure-a-bag smart contract infrastructure. Insure-a-bag is aiming to become the leading NFT insurance protocol, shaping the future of digital asset protection and security. We aim to create a thriving, interconnected ecosystem where creators, collectors, and investors can engage with NFTs confidently, knowing their assets are safeguarded by our innovative, decentralized, and comprehensive insurance solutions. Through continuous innovation, seamless integration, and community-driven development, we strive to build a resilient, inclusive, and sustainable platform that fosters growth and long-term success in the digital asset space.

## Installation

If this is your first time with Foundry, check out the
[installation](https://github.com/foundry-rs/foundry#installation) instructions.

## Technical details

InsureABag.sol is the main contract. The contract utilises the ERC721 standard to issue insurance policies. Through the `mintInsurancePolicy` and `mintInsurancePolicyApe` functions, users can mint insurance policies and insure tokens of supported collections. The protocol allows users to pay for the insurance policy with Ape tokens. By doing so, the protocol provides additional utility to the Ape token, outside the Yuga ecosystem.

Furthermore, through the `renewPolicy` and `renewPolicyApe` functions users can renew their existing policies by paying with Ethereum or ApeCoin. It is important to note that the expiery time is calculated in block time. In the case where a user renews a policy that has not expired yet, the contract takes the current expiery time and adds additional block time to it. On the other hand, if a user's insurance has expired, the function will calculate a new expiery time by adding the current block and duartion.

The contract utilises the Chainlink AggregatorV3Interface to obtain the price of Ape tokens. 

We've used [Foundry](https://book.getfoundry.sh/) for development, and this repository is created from the [PRB's foundry template](https://github.com/PaulRBerg/foundry-template).

## Deployment addresses

Goerli Insure A Bag: [0x8632bD6BE0cA0a7D4A5707F8f1Ff32D099bEefd4](https://goerli.etherscan.io/address/0x8632bD6BE0cA0a7D4A5707F8f1Ff32D099bEefd4)

Goerli Test Ape Coin [0xF102146713Ea1244eA8D364Ffe8085DD4068FC2c](https://goerli.etherscan.io/address/0xF102146713Ea1244eA8D364Ffe8085DD4068FC2c)

## License

[MIT](./LICENSE.md) © Insure A Bag


