import 'package:flutter/material.dart';
import 'package:silence_remover/src/router/router.dart';

class Homepage extends StatelessWidget{
  const Homepage( {super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Silence Remover"),backgroundColor: Theme.of(context).primaryColor,centerTitle: true,),
      body: Column(
          children: [
            const SizedBox(height: 10,),
            const Text("Welcome to Silence Remover."),
            Expanded(child: 
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  ElevatedButton.icon(onPressed: (){ // Record button.
                    RecordRoute().push(context);
                    },
                    icon: const Icon(Icons.mic),
                    label: const Text('Record something'),
                  ),
                  ElevatedButton.icon(onPressed: ()=>const RecordingExplorerRoute().push(context), // Browse button.
                    icon: const Icon(Icons.folder),
                    label: const Text('Browse Recorded files'),
                  ),
                ]),
              )
            ,)
          ],
        ),
    );
  }

}