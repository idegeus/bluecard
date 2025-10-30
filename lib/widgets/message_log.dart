import 'package:flutter/material.dart';

/// Herbruikbaar widget voor berichten log
class MessageLog extends StatelessWidget {
  final List<String> messages;
  
  const MessageLog({
    Key? key,
    required this.messages,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.article, color: Colors.grey[600], size: 20),
              SizedBox(width: 8),
              Text(
                'Berichten Log',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: 8),
        
        // Log container
        Expanded(
          child: Container(
            margin: EdgeInsets.all(16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[800]!),
            ),
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      'Nog geen berichten...',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: messages.length,
                    reverse: false,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          message,
                          style: TextStyle(
                            color: Colors.grey[300],
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
