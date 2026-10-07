import 'package:flutter/material.dart';

import '../td.dart';

/// TDesign 风格的选项组（选中态用品牌色描边 + 浅底）
class TdChoiceGroup<T> extends StatelessWidget {
  const TdChoiceGroup({
    super.key,
    required this.items,
    required this.selected,
    required this.onSelect,
    this.labelBuilder,
    this.itemWidth,
  });

  final List<T> items;
  final T? selected;
  final ValueChanged<T> onSelect;
  final String Function(T item)? labelBuilder;
  final double? itemWidth;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TdSpacer.xs,
      runSpacing: TdSpacer.xs,
      children: <Widget>[
        for (final item in items)
          _ChoiceItem(
            label: labelBuilder?.call(item) ?? '$item',
            selected: item == selected,
            width: itemWidth,
            onTap: () => onSelect(item),
          ),
      ],
    );
  }
}

class _ChoiceItem extends StatelessWidget {
  const _ChoiceItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.width,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: TdSpacer.small, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? TdPalette.brandLight : TdPalette.gray1,
          borderRadius: BorderRadius.circular(TdRadius.medium),
          border: Border.all(
            color: selected ? TdPalette.brand : Colors.transparent,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.3,
            color: selected ? TdPalette.brand : TdPalette.textPrimary,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 分段控件（进行中 / 已完成）
class TdSegmented extends StatelessWidget {
  const TdSegmented({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: TdPalette.gray1,
        borderRadius: BorderRadius.circular(TdRadius.medium),
      ),
      child: Row(
        children: <Widget>[
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: i == index ? TdPalette.container : Colors.transparent,
                    borderRadius: BorderRadius.circular(TdRadius.small),
                    boxShadow: i == index
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: i == index ? TdPalette.textPrimary : TdPalette.textSecondary,
                      fontWeight: i == index ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
