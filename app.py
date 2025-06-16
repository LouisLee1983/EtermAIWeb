#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
EtermAIWeb - 机票代理自动化云平台
Flask应用启动文件
"""

from flask import Flask, jsonify, render_template_string

app = Flask(__name__)

@app.route('/')
def index():
    """首页"""
    html_template = """
    <!DOCTYPE html>
    <html lang="zh-CN">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>EtermAIWeb - 机票代理自动化云平台</title>
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                margin: 0;
                padding: 0;
                min-height: 100vh;
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .container {
                background: white;
                border-radius: 20px;
                padding: 40px;
                box-shadow: 0 20px 40px rgba(0,0,0,0.1);
                text-align: center;
                max-width: 600px;
                margin: 20px;
            }
            h1 {
                color: #2c3e50;
                margin-bottom: 20px;
                font-size: 2.5em;
            }
            .subtitle {
                color: #7f8c8d;
                font-size: 1.2em;
                margin-bottom: 30px;
            }
            .status {
                background: #2ecc71;
                color: white;
                padding: 10px 20px;
                border-radius: 25px;
                display: inline-block;
                margin: 20px 0;
                font-weight: bold;
            }
            .features {
                text-align: left;
                margin: 30px 0;
            }
            .feature {
                margin: 10px 0;
                padding: 10px;
                background: #f8f9fa;
                border-radius: 8px;
                border-left: 4px solid #3498db;
            }
            .footer {
                margin-top: 30px;
                color: #95a5a6;
                font-size: 0.9em;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>🛩️ EtermAIWeb</h1>
            <div class="subtitle">机票代理自动化云平台</div>
            <div class="status">✅ 系统运行正常</div>
            
            <div class="features">
                <div class="feature">
                    <strong>🖥️ 终端管理</strong> - 统一管理全国各地的终端PC
                </div>
                <div class="feature">
                    <strong>📋 任务调度</strong> - 智能分配和调度Eterm自动化任务
                </div>
                <div class="feature">
                    <strong>👥 权限管理</strong> - 多角色权限管理系统
                </div>
                <div class="feature">
                    <strong>💰 计费系统</strong> - 精确的使用计费和统计功能
                </div>
                <div class="feature">
                    <strong>🔌 API接口</strong> - 开放的RESTful API接口
                </div>
            </div>
            
            <div class="footer">
                基于Eterm白屏破解的自动化操作系统<br>
                技术栈: Python 3.10 + Flask + Vue3.js + PostgreSQL
            </div>
        </div>
    </body>
    </html>
    """
    return render_template_string(html_template)

@app.route('/api/health')
def health_check():
    """健康检查接口"""
    return jsonify({
        'status': 'ok',
        'message': 'EtermAIWeb服务运行正常',
        'version': '1.0.0'
    })

@app.route('/api/status')
def status():
    """系统状态接口"""
    return jsonify({
        'system': 'EtermAIWeb',
        'description': '机票代理自动化云平台',
        'status': 'running',
        'features': [
            '终端管理',
            '任务调度', 
            '权限管理',
            '计费系统',
            'API接口'
        ]
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False) 