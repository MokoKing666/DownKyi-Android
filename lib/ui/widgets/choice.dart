import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';

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
    // 用官方 TDSelectTag（内部就是 TDTag）而不是自绘容器。
    // 选中 / 未选中两套样式通过 TDTagStyle 传入我们的主题令牌，
    // 所以既统一到 TDesign，又不会丢掉哔哩哔哩粉的配色。
    return TDSelectTag(
      label,
      isSelected: selected,
      size: TDTagSize.small,
      shape: TDTagShape.square,
      fixedWidth: width,
      padding:
          const EdgeInsets.symmetric(horizontal: TdSpacer.small, vertical: 7),
      selectStyle: TDTagStyle(
        context: context,
        textColor: TdPalette.brand,
        backgroundColor: TdPalette.brandLight,
        border: 1,
        borderColor: TdPalette.brand,
        borderRadius: BorderRadius.circular(TdRadius.medium),
      ),
      unSelectStyle: TDTagStyle(
        context: context,
        textColor: TdPalette.textPrimary,
        backgroundColor: TdPalette.gray1,
        border: 0,
        borderRadius: BorderRadius.circular(TdRadius.medium),
      ),
      onSelectChanged: (_) => onTap(),
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
      margin: const EdgeInsets.symmetric(
          horizontal: TdSpacer.medium, vertical: TdSpacer.xs),
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
                    color:
                        i == index ? TdPalette.container : Colors.transparent,
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
                      color: i == index
                          ? TdPalette.textPrimary
                          : TdPalette.textSecondary,
                      fontWeight:
                          i == index ? FontWeight.w500 : FontWeight.w400,
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
