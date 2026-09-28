# story.md

It was 2:14 AM on a Tuesday when the fictional trading platform, *ApexTrade*, started bleeding digital money. 

As the newly hired engineer, I was staring at a database dashboard that defied logic. A user had a wallet balance of negative $40,000. Another user had just bought 500 shares of a tech stock, but the cash was never deducted from their account. Worst of all, the total cash in the system's master ledger didn't match the sum of the user wallets.

I dug into the legacy code and discovered a house of cards built on terrible database practices:

1. **The Floating Point Phantom:** The previous developers stored user balances using `FLOAT` instead of strict `DECIMAL`. Tiny fraction rounding errors compounded until thousands of real dollars evaporated into the ether.
2. **The Double-Spend Disaster:** A malicious user spammed the "Buy" button ten times in a single millisecond. The database blindly accepted simultaneous commands without row-level locks, allowing them to buy assets with money they didn't have.
3. **The Torn Transaction:** A server crashed mid-trade. The system deducted $1,000 from a wallet but died before inserting the shares into the portfolio. Without strict ACID transactions, the database permanently swallowed the user's money.

I decided to wipe the slate clean. I am building a brand new investing platform from scratch, but this time, it is database-first. I will build an engine that cannot be broken, utilizing strict constraints, ACID compliance, and concurrency control.