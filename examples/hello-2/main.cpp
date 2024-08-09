#include <QtWidgets/QApplication>
#include <QLabel>

int main(int argc, char *argv[]) {
  QApplication app(argc, argv);
  app.setOverrideCursor(Qt::BlankCursor);

  QLabel label("It works!");
  label.setAlignment(Qt::AlignCenter);
  label.setStyleSheet("font-size: 50px");
  label.show();

  return app.exec();
}
