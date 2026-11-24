import Foundation

/// Ticker symbol to CoinGecko coin id for the most traded coins.
enum CoinMap {
    static let ids: [String: String] = [
        "BTC": "bitcoin", "ETH": "ethereum", "USDT": "tether", "BNB": "binancecoin", "SOL": "solana",
        "XRP": "ripple", "USDC": "usd-coin", "ADA": "cardano", "DOGE": "dogecoin", "TRX": "tron",
        "TON": "the-open-network", "DOT": "polkadot", "LTC": "litecoin", "BCH": "bitcoin-cash",
        "LINK": "chainlink", "XLM": "stellar", "AVAX": "avalanche-2", "SHIB": "shiba-inu",
        "MATIC": "matic-network", "POL": "polygon-ecosystem-token", "XMR": "monero", "ATOM": "cosmos",
        "UNI": "uniswap", "ETC": "ethereum-classic", "FIL": "filecoin", "NEAR": "near", "APT": "aptos",
        "ARB": "arbitrum", "OP": "optimism", "ALGO": "algorand", "VET": "vechain", "AAVE": "aave",
        "HBAR": "hedera-hashgraph", "ICP": "internet-computer", "INJ": "injective-protocol", "DAI": "dai",
        "SUI": "sui", "PEPE": "pepe", "KAS": "kaspa",
    ]
}
