import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:get_it/get_it.dart';

import '../../state/audio_store.dart';
import '../../theming.dart';

class SleepTimer extends StatelessWidget {
  const SleepTimer() : super();

  @override
  Widget build(BuildContext context) {
    final AudioStore audioStore = GetIt.I<AudioStore>();
    return ListTile(
      title: Text(L10n.of(context)!.sleepTimer),
      leading: const Icon(Icons.access_alarm),
      onTap: () {
        Navigator.of(context, rootNavigator: true).pop();
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return Observer(
                builder: (context) {
                  const List<int> times = [5, 10, 15, 30, 45, 60, 90, 120];
                  return SimpleDialog(
                    backgroundColor: DARK3,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.all(HORIZONTAL_PADDING),
                        child: Container(
                          height: 300.0,
                          width: 300.0,
                          child: ListView.separated(
                            itemCount: times.length,
                            itemBuilder: (_, int index) {
                              final time = times[index];
                              return ListTile(
                                  title: Text('${time}min'),
                                  onTap: () {
                                    audioStore.setSleepTimer(time);
                                    //TODO: set timer to x
                                    Navigator.pop(context);
                                  });
                            },
                            separatorBuilder:
                                (BuildContext context, int index) =>
                                    const SizedBox(
                              height: 4.0,
                            ),
                          ),
                        ),
                      ),
                      SimpleDialogOption(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(
                          L10n.of(context)!.cancel,
                          textAlign: TextAlign.right,
                        ),
                      )
                    ],
                  );
                },
              );
            });
      },
    );
  }
}
