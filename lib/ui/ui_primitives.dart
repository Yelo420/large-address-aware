import 'package:flutter/material.dart';

const BorderRadius workspacePanelRadius = BorderRadius.all(Radius.circular(22));
const List<BoxShadow> workspacePanelShadow = <BoxShadow>[
  BoxShadow(
    color: Color(0x11000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  ),
];

List<Widget> addHorizontalSpacing(
  List<Widget> children, {
  double spacing = 8,
}) {
  if (children.isEmpty) {
    return const <Widget>[];
  }

  final spacedChildren = <Widget>[];
  for (var index = 0; index < children.length; index++) {
    if (index > 0) {
      spacedChildren.add(SizedBox(width: spacing));
    }
    spacedChildren.add(children[index]);
  }

  return spacedChildren;
}

class WorkspacePanel extends StatelessWidget {
  const WorkspacePanel({
    required this.child,
    this.borderColor = const Color(0xFFD8D5C9),
    super.key,
  });

  final Widget child;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: workspacePanelRadius,
        border: Border.all(color: borderColor),
        boxShadow: workspacePanelShadow,
      ),
      child: child,
    );
  }
}