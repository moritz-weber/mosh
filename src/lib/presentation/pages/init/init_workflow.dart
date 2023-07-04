import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:page_indicator_plus/page_indicator_plus.dart';

import '../../../domain/repositories/init_repository.dart';
import '../../state/import_store.dart';
import '../../theming.dart';
import 'init_battery_page.dart';
import 'init_lib_page.dart';
import 'init_meta_page.dart';

class InitWorkflow extends StatefulWidget {
  const InitWorkflow({super.key, this.importPath});

  final String? importPath;

  @override
  State<InitWorkflow> createState() => _InitWorkflowState();
}

class _InitWorkflowState extends State<InitWorkflow> {
  PageController pageController = PageController();
  int index = 0;

  late final ImportStore importStore;
  late final List<Widget> pages = [
    InitLibPage(importStore: importStore),
  ];

  final curve = Curves.easeInOut;
  final duration = const Duration(milliseconds: 400);

  @override
  void initState() {
    importStore = GetIt.I<ImportStore>(param1: widget.importPath);
    if (widget.importPath != null) {
      importStore.readDataFile(widget.importPath!).then((_) {
        if (importStore.songs?.isNotEmpty ?? false)
          setState(() => pages.add(InitMetaPage(importStore: importStore)));
        DeviceInfoPlugin().androidInfo.then((info) {
          if (info.version.sdkInt > 30)
            setState(() => pages.add(InitBatteryPage(importStore: importStore)));
        });
      });
    } else {
      DeviceInfoPlugin().androidInfo.then((info) {
        if (info.version.sdkInt > 30)
          setState(() => pages.add(InitBatteryPage(importStore: importStore)));
      });
    }

    super.initState();
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TODO: this does not conform to the design that UI should only call stores, but this would seem overkill
    final initRepository = GetIt.I<InitRepository>();

    return Scaffold(
      bottomNavigationBar: Container(
        color: DARK1,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: HORIZONTAL_PADDING,
                vertical: 8.0,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton(
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chevron_left_rounded),
                            Text('Back'),
                            SizedBox(width: 10),
                          ],
                        ),
                        onPressed: () {
                          if (pageController.page?.round() == 0) {
                            Navigator.of(context).pop();
                          } else {
                            pageController.previousPage(duration: duration, curve: curve).then((_) {
                              setState(() {
                                index = pageController.page?.round() ?? 0;
                              });
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  PageIndicator(
                    controller: pageController,
                    count: pages.length,
                    size: 8,
                    layout: PageIndicatorLayout.WARM,
                    color: Colors.white10,
                    activeColor: LIGHT1,
                    scale: 0.65,
                    space: 10,
                  ),
                  Expanded(
                    child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 10),
                              Text(
                                index == pages.length - 1 ? 'Finish' : 'Next',
                              ),
                              const Icon(Icons.chevron_right_rounded),
                            ],
                          ),
                          onPressed: () {
                            if (index == pages.length - 1) {
                              initRepository.setInitialized();
                              Navigator.of(context).pop();
                              Navigator.of(context).pop();
                            } else {
                              setState(() {
                                pageController.nextPage(duration: duration, curve: curve).then((_) {
                                  setState(() {
                                    index = pageController.page?.round() ?? 0;
                                  });
                                });
                              });
                            }
                          },
                        )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: PageView.builder(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: pages.length,
        itemBuilder: (context, i) => pages[i],
      ),
    );
  }
}
