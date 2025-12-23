import Foundation

/// 무한매수법 V3.0 계산 유틸리티
struct InfiniteBuyingCalculations {

    /// 초기 1회 매수금 계산
    static func calculateInitialBuyAmount(seedMoney: Double, divisions: Int) -> Double {
        seedMoney / Double(divisions)
    }

    /// T값 계산 (소수점 2자리 올림)
    static func calculateTValue(totalBuyAmount: Double, buyAmountPerTrade: Double) -> Double {
        guard buyAmountPerTrade > 0 else { return 0 }
        let rawT = totalBuyAmount / buyAmountPerTrade
        return (rawT * 100).rounded(.up) / 100
    }

    /// 별% 계산
    /// 별% = 매도목표% - (매도목표% / (분할수/2)) × T
    static func calculateStarPercent(sellTargetPercent: Double, divisions: Int, tValue: Double) -> Double {
        let halfDivisions = Double(divisions) / 2
        guard halfDivisions > 0 else { return sellTargetPercent }
        return sellTargetPercent - (sellTargetPercent / halfDivisions) * tValue
    }

    /// 전반전 여부 (T < 분할수/2)
    static func isFirstHalf(tValue: Double, divisions: Int) -> Bool {
        tValue < Double(divisions) / 2
    }

    /// 반복리 적용 후 새 1회 매수금 계산
    static func calculateNewBuyAmount(
        currentBuyAmount: Double,
        profit: Double,
        compoundRate: Double,
        seedMoney: Double,
        divisions: Int
    ) -> Double {
        let compoundProfit = profit * (compoundRate / 100)
        let newBuyAmount = currentBuyAmount + (compoundProfit / Double(divisions))
        let initialBuyAmount = seedMoney / Double(divisions)
        return max(newBuyAmount, initialBuyAmount)
    }

    /// 평균단가 계산
    static func calculateAveragePrice(totalBuyAmount: Double, totalQuantity: Int) -> Double {
        guard totalQuantity > 0 else { return 0 }
        return totalBuyAmount / Double(totalQuantity)
    }

    /// 손익분기단가 계산
    static func calculateBreakEvenPrice(totalBuyAmount: Double, totalFee: Double, totalQuantity: Int) -> Double {
        guard totalQuantity > 0 else { return 0 }
        return (totalBuyAmount + totalFee) / Double(totalQuantity)
    }

    /// 시드 소진율 계산
    static func calculateSeedUsageRate(totalBuyAmount: Double, seedMoney: Double) -> Double {
        guard seedMoney > 0 else { return 0 }
        return (totalBuyAmount / seedMoney) * 100
    }

    /// 평가손익 계산
    static func calculateUnrealizedProfit(valuation: Double, totalBuyAmount: Double) -> Double {
        valuation - totalBuyAmount
    }

    /// 지정가 매도가 계산
    static func calculateLimitSellPrice(averagePrice: Double, sellTargetPercent: Double) -> Double {
        averagePrice * (1 + sellTargetPercent / 100)
    }

    /// RSI 기반 권장값 계산
    static func calculateRsiRecommend(rsi: Double) -> Double {
        if rsi <= 30 {
            return 30
        } else if rsi <= 50 {
            return 50
        } else {
            return 70
        }
    }
}

// MARK: - Constants
extension InfiniteBuyingCalculations {
    /// 지원 종목 목록
    static let supportedSymbols: [String] = [
        "TQQQ", "SOXL", "TECL", "FNGU", "UPRO",
        "WEBL", "BULZ", "WANT", "DFEN", "HIBL",
        "TNA", "UDOW", "LABU", "NAIL", "RETL",
        "DPST", "DUSL", "MIDU", "FAS", "CURE"
    ]

    /// V3.0 기본 설정
    struct V3Defaults {
        static let divisions = 20
        static let sellTargetPercentTQQQ = 15.0
        static let sellTargetPercentSOXL = 20.0
        static let compoundRate = 50.0
    }

    /// V2.2 기본 설정
    struct V2Defaults {
        static let divisions = 40
        static let sellTargetPercentTQQQ = 10.0
        static let sellTargetPercentSOXL = 12.0
        static let compoundRate = 0.0
    }
}
