import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SmzPage extends StatefulWidget {
  const SmzPage({super.key});

  @override
  State<SmzPage> createState() => _SmzPageState();
}

class _SmzPageState extends State<SmzPage> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('舌面诊'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 头部区域
          _buildHeader(),
          // 主要内容区域
          Expanded(
            child: SingleChildScrollView(
              controller: _controller,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 舌部部分
                  _buildSectionTitle('舌部'),
                  const SizedBox(height: 16),
                  _buildImageUploadRow('舌面', '示例'),
                  const SizedBox(height: 16),
                  _buildImageUploadRow('舌下脉络', '示例'),
                  const SizedBox(height: 32),
                  // 面部部分
                  _buildSectionTitle('面部'),
                  const SizedBox(height: 16),
                  _buildImageUploadRow('正面', '示例'),
                  const SizedBox(height: 100), // 为底部按钮留出空间
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomButton(),
    );
  }

  // 头部区域
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9), // 浅绿色背景
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          // 左侧房子图标
          IconButton(
            icon: const Icon(Icons.home, color: Colors.grey),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 8),
          // 中间标题和副标题
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '舌面分析',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '极速识别舌面异常',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          // 右侧图标（舌头扫描效果）
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.green[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face,
              size: 30,
              color: Colors.green[700],
            ),
          ),
        ],
      ),
    );
  }

  // 部分标题
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  // 图片上传行
  Widget _buildImageUploadRow(String label, String exampleText) {
    return Row(
      children: [
        // 左侧上传框
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: () {
              // TODO: 实现图片选择功能
            },
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey[300]!,
                  style: BorderStyle.solid,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 40,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // 右侧示例图片
        Expanded(
          flex: 2,
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  label == '舌面' || label == '舌下脉络'
                      ? Icons.face
                      : Icons.person,
                  size: 50,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  exampleText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 底部确定按钮
  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () {
              // TODO: 实现确定功能
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF81C784), // 浅绿色
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              '确定',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
