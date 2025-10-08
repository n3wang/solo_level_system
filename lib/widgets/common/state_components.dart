// lib/widgets/common/state_components.dart
import 'package:flutter/material.dart';

/// A reusable loading indicator component
class LoadingIndicator extends StatelessWidget {
  final String? message;
  final Color? color;

  const LoadingIndicator({
    Key? key,
    this.message,
    this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: color ?? Theme.of(context).primaryColor,
          ),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A reusable empty state component
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyState({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: iconColor ?? Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: 8),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
          if (action != null) ...[
            SizedBox(height: 16),
            action!,
          ],
        ],
      ),
    );
  }
}

/// A reusable error state component
class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final String retryText;

  const ErrorState({
    Key? key,
    required this.title,
    this.message,
    this.onRetry,
    this.retryText = 'Retry',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.red[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (message != null) ...[
            SizedBox(height: 8),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
          if (onRetry != null) ...[
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(retryText),
            ),
          ],
        ],
      ),
    );
  }
}

/// A reusable tabbed loading wrapper
class TabbedScreenWrapper extends StatelessWidget {
  final bool isLoading;
  final String? loadingMessage;
  final Widget Function() builder;

  const TabbedScreenWrapper({
    Key? key,
    required this.isLoading,
    this.loadingMessage,
    required this.builder,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: LoadingIndicator(message: loadingMessage),
      );
    }

    return builder();
  }
}