part of my_fatoorah;

class LoadingState {
  final bool loading;
  final String? error;
  bool get hasError => error != null;

  LoadingState(this.loading, this.error);
}

class _PaymentMethodsBuilder extends StatefulWidget {
  final MyfatoorahRequest request;
  final PreferredSizeWidget Function(BuildContext context)? getAppBar;
  final bool showServiceCharge;
  final Widget Function(List<PaymentMethod> methods, LoadingState state,
      Future<PaymentResponse> Function(PaymentMethod submit) onSelect)? builder;
  final Widget? errorChild;
  final Widget? succcessChild;
  final AfterPaymentBehaviour afterPaymentBehaviour;
  final Function(PaymentResponse res)? onResult;

  /// Filter payment methods after fetching it
  final List<PaymentMethod> Function(List<PaymentMethod> methods)?
      filterPaymentMethods;
  const _PaymentMethodsBuilder({
    Key? key,
    required this.request,
    this.builder,
    required this.showServiceCharge,
    this.errorChild,
    this.succcessChild,
    required this.afterPaymentBehaviour,
    this.getAppBar,
    this.filterPaymentMethods,
    this.onResult,
  }) : super(key: key);
  @override
  _PaymentMethodsBuilderState createState() => _PaymentMethodsBuilderState();
}

class _PaymentMethodsBuilderState extends State<_PaymentMethodsBuilder>
    with TickerProviderStateMixin {
  List<PaymentMethod> methods = [];
  bool loading = true;
  String? errorMessage;

  Future loadMethods() {
    var url = widget.request.initiatePaymentUrl ??
        '${widget.request.url}/v2/InitiatePayment';

    return http.post(Uri.parse(url),
        body: jsonEncode(widget.request.intiatePaymentRequest()),
        headers: {
          "Content-Type": "application/json",
          "Authorization":
              "bearer ${widget.request.token.replaceAll("bearer ", "")}",
        }).then((response) {
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var _response = _InitiatePaymentResponse.fromJson(json);
        if (widget.filterPaymentMethods != null && _response.data != null)
          _response.data!.paymentMethods =
              widget.filterPaymentMethods!(_response.data!.paymentMethods);
        setState(() {
          methods = _response.isSuccess
              ? _response.data!.paymentMethods
                  .map((e) => e.withLangauge(widget.request.language))
                  .toList()
              : [];
          errorMessage = _response.isSuccess ? null : _response.message;
          loading = false;
        });
      } else {
        setState(() {
          loading = false;
          errorMessage = response.body;
        });
      }
    }).catchError((e) {
      print(e);
      setState(() {
        loading = false;
        errorMessage = e.toString();
      });
    });
  }

  @override
  void initState() {
    loadMethods();

    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(PaymentResponse(PaymentStatus.None));

        return false;
      },
      child: AnimatedSize(
        vsync: this,
        duration: Duration(milliseconds: 300),
        child: buildChild(),
      ),
    );
  }

  Widget buildChild() {
    if (widget.builder != null)
      return widget.builder!(methods, LoadingState(loading, errorMessage),
          (method) async {
        var result =
            await _PaymentMethodItem.loadExcustion(widget.request, method);
        if (!result.isSuccess) throw result.message;
        return _showWebView(result.data!.paymentURL);
      });
    if (loading == true) {
      return buildLoading();
    } else if (errorMessage != null) {
      return buildError();
    } else {
      return ListView(
        shrinkWrap: true,
        children: ListTile.divideTiles(
          color: Colors.black26,
          tiles: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
              child: Text(
                widget.request.invoiceAmount.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var method in methods)
              _PaymentMethodItem(
                showServiceCharge: widget.showServiceCharge,
                method: method.withLangauge(widget.request.language),
                request: widget.request,
                onLaunch: (String _url) {
                  _showWebView(_url);
                },
              )
          ],
        ).toList(),
      );
    }
  }

  Future<PaymentResponse> _showWebView(String url) async {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _WebViewPage(
          uri: Uri.parse(url),
          getAppBar: widget.getAppBar,
          errorChild: widget.errorChild,
          succcessChild: widget.succcessChild,
          successUrl: widget.request.successUrl,
          errorUrl: widget.request.errorUrl,
          afterPaymentBehaviour: widget.afterPaymentBehaviour,
        ),
      ),
    ).then((value) {
      if (widget.onResult == null) {
        if (value is PaymentResponse) {
          if (value.status != PaymentStatus.None) {
            Navigator.of(context).pop(value);
          }
        }
      } else {
        if (value is PaymentResponse) widget.onResult!(value);
      }

      return value;
    });
  }

  Widget buildError() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IconButton(
            icon: Icon(Icons.warning),
            iconSize: 50,
            onPressed: () {
              setState(() {
                loading = true;
              });
              loadMethods();
            },
          ),
          SizedBox(height: 15),
          Text(
            errorMessage ?? "",
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  SizedBox buildLoading() {
    return SizedBox(
      height: 100,
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
