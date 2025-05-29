import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CommentBubble extends StatelessWidget {
  final String text;
  final Timestamp? timestamp;
  final String phoneNumber;
  final bool isCurrentUser;

  const CommentBubble({
    Key? key,
    required this.text,
    required this.timestamp,
    required this.phoneNumber,
    required this.isCurrentUser,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format the timestamp
    String formattedTimestamp =
        timestamp != null
            ? DateFormat('HH:mm').format(timestamp!.toDate())
            : 'Unknown time';

    // Mask phone number for privacy
    String maskedPhoneNumber =
        phoneNumber.isNotEmpty
            ? phoneNumber.replaceRange(0, phoneNumber.length - 4, '****')
            : 'Unknown user';

    return Container(
      padding: const EdgeInsets.all(10.0),
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isCurrentUser ? const Color(0xFFDCF8C6) : Colors.grey[300], // Cambiado a un verde tipo WhatsApp para comentarios propios
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.0),
          topRight: Radius.circular(12.0),
          bottomLeft:
              isCurrentUser ? Radius.circular(12.0) : Radius.circular(2.0),
          bottomRight:
              isCurrentUser ? Radius.circular(2.0) : Radius.circular(12.0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phone number centered and formatted
          Center(
            child: Text(
              'COMENTADO POR: $maskedPhoneNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.0,
              ), // Phone number size
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 4.0),
          // Comment text - increased size, bold, white color, italic
          Text(
            text,
            style: TextStyle(
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
              color: Colors.black, // Cambiado el color del texto a negro para que contraste con el fondo verde
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: 4.0),
          // Timestamp aligned to the right and bold
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formattedTimestamp,
              style: TextStyle(
                fontSize: 12.0,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ), // Timestamp bold
            ),
          ),
        ],
      ),
    );
  }
}
