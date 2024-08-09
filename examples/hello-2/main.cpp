#include <QtWidgets/QApplication>
#include <QLabel>

int main(int argc, char *argv[]) {
  QApplication app(argc, argv);
  app.setOverrideCursor(Qt::BlankCursor);

  QString message = qgetenv("MESSAGE");
  QString text = QString("%1").arg(
    !message.isNull() ? message : "Lorem ipsum dolor sit amet..."
  );

  QLabel label(text);
  label.setAlignment(Qt::AlignCenter);
  label.setStyleSheet("font-size: 50px");
  label.show();

  return app.exec();
}
