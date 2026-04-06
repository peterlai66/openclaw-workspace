#!/usr/bin/env python3
"""
簡化版台灣股市數據獲取腳本
不使用pandas，純Python實現
"""

import requests
import json
from datetime import datetime, timedelta
import yaml
import os
import sys

# 讀取API配置
def load_api_config():
    config_path = "/home/pclaw/.openclaw/workspace/api_config.yaml"
    with open(config_path, 'r') as f:
        config = yaml.safe_load(f)
    return config

# 獲取FinMind數據
def get_finmind_data(token, stock_ids, start_date=None, end_date=None):
    """從FinMind獲取股票數據"""
    if start_date is None:
        start_date = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
    if end_date is None:
        end_date = datetime.now().strftime('%Y-%m-%d')
    
    base_url = "https://api.finmindtrade.com/api/v4/data"
    
    results = {}
    
    for stock_id in stock_ids:
        try:
            # 獲取股價數據
            params = {
                'dataset': 'TaiwanStockPrice',
                'data_id': stock_id,
                'start_date': start_date,
                'end_date': end_date,
                'token': token
            }
            
            response = requests.get(base_url, params=params)
            if response.status_code == 200:
                data = response.json()
                if data.get('status') == 200:
                    results[stock_id] = {
                        'price_data': data.get('data', []),
                        'last_update': datetime.now().isoformat()
                    }
            else:
                print(f"獲取{stock_id}股價數據失敗: HTTP {response.status_code}")
                
        except Exception as e:
            print(f"處理{stock_id}時發生錯誤: {e}")
    
    return results

# 獲取Fugle即時數據
def get_fugle_data(api_key, stock_ids):
    """從Fugle獲取即時技術分析數據"""
    base_url = "https://api.fugle.tw/realtime/v0.3/intraday"
    results = {}
    
    for stock_id in stock_ids:
        try:
            url = f"{base_url}/quote/{stock_id}"
            headers = {
                'X-API-KEY': api_key
            }
            
            response = requests.get(url, headers=headers)
            if response.status_code == 200:
                data = response.json()
                results[stock_id] = {
                    'realtime': data,
                    'last_update': datetime.now().isoformat()
                }
            else:
                print(f"獲取{stock_id}即時數據失敗: HTTP {response.status_code}")
                
        except Exception as e:
            print(f"處理{stock_id}即時數據時發生錯誤: {e}")
    
    return results

# 獲取大盤指數數據
def get_taiwan_index_data(token):
    """獲取台灣加權指數數據"""
    base_url = "https://api.finmindtrade.com/api/v4/data"
    
    # 獲取加權指數
    params = {
        'dataset': 'TaiwanStockPrice',
        'data_id': 'TAIEX',
        'start_date': (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d'),
        'end_date': datetime.now().strftime('%Y-%m-%d'),
        'token': token
    }
    
    try:
        response = requests.get(base_url, params=params)
        if response.status_code == 200:
            data = response.json()
            if data.get('status') == 200:
                return data.get('data', [])
    except Exception as e:
        print(f"獲取大盤指數數據失敗: {e}")
    
    return []

# 分析技術指標
def analyze_technical_data(price_data):
    """分析技術指標"""
    if not price_data:
        return {}
    
    # 手動計算技術指標
    closes = [float(item['close']) for item in price_data if 'close' in item]
    volumes = [int(item.get('Trading_Volume', 0)) for item in price_data if 'Trading_Volume' in item]
    
    if not closes:
        return {}
    
    # 最新價格
    current_price = closes[-1]
    
    # 計算漲跌幅
    if len(closes) > 1:
        prev_price = closes[-2]
        change_percent = ((current_price - prev_price) / prev_price) * 100
    else:
        change_percent = 0
    
    # 計算移動平均線
    ma5 = sum(closes[-5:]) / min(5, len(closes)) if closes else 0
    ma20 = sum(closes[-20:]) / min(20, len(closes)) if closes else 0
    
    # 計算RSI（簡化版）
    if len(closes) >= 14:
        gains = []
        losses = []
        for i in range(1, 15):
            change = closes[-i] - closes[-i-1] if len(closes) > i else 0
            if change > 0:
                gains.append(change)
                losses.append(0)
            else:
                gains.append(0)
                losses.append(abs(change))
        
        avg_gain = sum(gains) / len(gains) if gains else 0
        avg_loss = sum(losses) / len(losses) if losses else 0
        
        if avg_loss == 0:
            rsi = 100
        else:
            rs = avg_gain / avg_loss
            rsi = 100 - (100 / (1 + rs))
    else:
        rsi = 50
    
    # 支撐和阻力位
    support = min(closes) if closes else 0
    resistance = max(closes) if closes else 0
    
    # 趨勢判斷
    if ma5 > ma20:
        trend = '上升'
    elif ma5 < ma20:
        trend = '下降'
    else:
        trend = '盤整'
    
    analysis = {
        'current_price': current_price,
        'change_percent': change_percent,
        'volume': volumes[-1] if volumes else 0,
        'ma5': ma5,
        'ma20': ma20,
        'rsi': rsi,
        'support_level': support,
        'resistance_level': resistance,
        'trend': trend
    }
    
    return analysis

# 生成分析報告
def generate_analysis_report(finmind_data, fugle_data, index_data):
    """生成完整的分析報告"""
    report = {
        'report_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'market_overview': {},
        'stocks': {},
        'technical_analysis': {},
        'risk_assessment': {},
        'recommendations': {}
    }
    
    # 分析大盤指數
    if index_data:
        # 找到最新數據
        latest_index = index_data[-1] if index_data else {}
        
        report['market_overview'] = {
            'index_value': float(latest_index.get('close', 0)) if latest_index else 0,
            'index_change': float(latest_index.get('change', 0)) if latest_index else 0,
            'index_change_percent': float(latest_index.get('change_percent', 0)) if latest_index else 0,
            'index_volume': int(latest_index.get('Trading_Volume', 0)) if latest_index else 0,
            'market_trend': '上漲' if latest_index.get('change', 0) > 0 else '下跌' if latest_index.get('change', 0) < 0 else '平盤'
        }
    
    # 分析重點股票
    focus_stocks = ['2330', '0050', '2412']
    
    for stock_id in focus_stocks:
        stock_report = {
            'technical': {},
            'realtime': {},
            'analysis': {}
        }
        
        # 技術分析
        if stock_id in finmind_data and 'price_data' in finmind_data[stock_id]:
            tech_analysis = analyze_technical_data(finmind_data[stock_id]['price_data'])
            stock_report['technical'] = tech_analysis
        
        # 即時數據
        if stock_id in fugle_data:
            stock_report['realtime'] = fugle_data[stock_id]
        
        # 綜合分析
        if stock_report['technical']:
            tech = stock_report['technical']
            stock_report['analysis'] = {
                'trend_strength': '強' if abs(tech.get('change_percent', 0)) > 3 else '中等' if abs(tech.get('change_percent', 0)) > 1 else '弱',
                'rsi_signal': '超買' if tech.get('rsi', 50) > 70 else '超賣' if tech.get('rsi', 50) < 30 else '中性',
                'ma_signal': '黃金交叉' if tech.get('ma5', 0) > tech.get('ma20', 0) and tech.get('trend') == '上升' else '死亡交叉' if tech.get('ma5', 0) < tech.get('ma20', 0) and tech.get('trend') == '下降' else '盤整'
            }
        
        report['stocks'][stock_id] = stock_report
    
    # 風險評估
    report['risk_assessment'] = {
        'market_risk': '低' if report['market_overview'].get('index_change_percent', 0) < 2 else '中等' if report['market_overview'].get('index_change_percent', 0) < 5 else '高',
        'volatility_risk': '低' if abs(report['market_overview'].get('index_change_percent', 0)) < 1 else '中等' if abs(report['market_overview'].get('index_change_percent', 0)) < 3 else '高',
        'liquidity_risk': '低',
        'sector_risk': {
            'semiconductor': '中等' if '2330' in report['stocks'] and report['stocks']['2330']['technical'].get('change_percent', 0) < 0 else '低',
            'telecom': '低' if '2412' in report['stocks'] else '中等',
            'etf': '低' if '0050' in report['stocks'] else '中等'
        }
    }
    
    # 投資建議
    report['recommendations'] = {
        'short_term': [],
        'medium_term': [],
        'long_term': []
    }
    
    # 根據分析生成建議
    for stock_id, data in report['stocks'].items():
        tech = data.get('technical', {})
        analysis = data.get('analysis', {})
        
        if stock_id == '2330':  # 台積電
            if tech.get('rsi', 50) < 40 and analysis.get('trend_strength') == '強':
                report['recommendations']['short_term'].append(f"{stock_id}: 逢低買入，目標價 {tech.get('current_price', 0) * 1.05:.0f}")
            elif tech.get('rsi', 50) > 70:
                report['recommendations']['short_term'].append(f"{stock_id}: 考慮獲利了結")
            else:
                report['recommendations']['short_term'].append(f"{stock_id}: 持有")
        
        elif stock_id == '2412':  # 中華電
            if abs(tech.get('change_percent', 0)) < 1:
                report['recommendations']['short_term'].append(f"{stock_id}: 防守型配置，適合長期持有")
        
        elif stock_id == '0050':  # 台灣50
            report['recommendations']['medium_term'].append(f"{stock_id}: 定期定額投資，分散風險")
    
    # 添加一般建議
    report['recommendations']['general'] = [
        "控制單一個股風險，避免過度集中",
        "保持現金比例10-15%以應對市場波動",
        "關注成交量變化，確認趨勢有效性"
    ]
    
    return report

def main():
    print("開始獲取台灣股市數據...")
    
    # 加載配置
    config = load_api_config()
    
    finmind_token = config['apis']['finmind']['token']
    fugle_api_key = config['apis']['fugle']['api_key']
    
    # 重點關注股票
    focus_stocks = ['2330', '0050', '2412']
    
    print("1. 獲取FinMind數據...")
    finmind_data = get_finmind_data(finmind_token, focus_stocks)
    
    print("2. 獲取Fugle即時數據...")
    fugle_data = get_fugle_data(fugle_api_key, focus_stocks)
    
    print("3. 獲取大盤指數數據...")
    index_data = get_taiwan_index_data(finmind_token)
    
    print("4. 生成分析報告...")
    report = generate_analysis_report(finmind_data, fugle_data, index_data)
    
    # 保存報告
    output_path = "/home/pclaw/.openclaw/workspace/finance/market_analysis.json"
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(report, f, ensure_ascii=False, indent=2)
    
    print(f"分析完成！報告已保存至: {output_path}")
    
    # 輸出摘要
    print("\n=== 市場摘要 ===")
    market = report.get('market_overview', {})
    print(f"加權指數: {market.get('index_value', 0):.2f} ({market.get('index_change_percent', 0):+.2f}%)")
    print(f"市場趨勢: {market.get('market_trend', 'N/A')}")
    
    print("\n=== 重點股票分析 ===")
    for stock_id, data in report.get('stocks', {}).items():
        tech = data.get('technical', {})
        print(f"{stock_id}: {tech.get('current_price', 0):.2f} ({tech.get('change_percent', 0):+.2f}%), RSI: {tech.get('rsi', 0):.1f}, 趨勢: {tech.get('trend', 'N/A')}")
    
    return report

if __name__ == "__main__":
    main()