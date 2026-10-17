#pragma once

#include <string>
#include <vector>
#include <chrono>
#include <algorithm>
#include <sstream>
#include <cctype>
#include <fstream>

#ifndef QT_VERSION

#define Q_OBJECT
#define signals public
#define slots
#define emit

#define Q_DECLARE_METATYPE(x)

namespace Qt {
    enum SplitBehavior { KeepEmptyParts, SkipEmptyParts };
}

class QJsonObject {};
class QJsonArray {};

class QString;
class QStringList;

class QString : public std::string {
public:
    QString() : std::string() {}
    QString(const char* s) : std::string(s ? s : "") {}
    QString(const std::string& s) : std::string(s) {}

    static QString fromUtf8(const char* s) { return QString(s); }
    static QString fromUtf8(const char* s, int size) { return QString(std::string(s, size)); }
    static QString fromUtf8(const std::string& s) { return QString(s); }

    bool isEmpty() const { return empty(); }
    QString trimmed() const {
        std::string s = *this;
        s.erase(s.begin(), std::find_if(s.begin(), s.end(), [](unsigned char ch) { return !std::isspace(ch); }));
        s.erase(std::find_if(s.rbegin(), s.rend(), [](unsigned char ch) { return !std::isspace(ch); }).base(), s.end());
        return QString(s);
    }

    std::wstring toStdWString() const {
        return std::wstring(begin(), end());
    }

    const char* constData() const { return c_str(); }
    QString toUtf8() const { return *this; }

    template<typename T>
    QString arg(T val) const {
        std::stringstream ss;
        ss << val;
        std::string search = "%1";
        std::string s = *this;
        size_t pos = s.find(search);
        if (pos != std::string::npos) {
            s.replace(pos, search.length(), ss.str());
        } else {
            search = "%2";
            pos = s.find(search);
            if (pos != std::string::npos) {
                s.replace(pos, search.length(), ss.str());
            } else {
                search = "%3";
                pos = s.find(search);
                if (pos != std::string::npos) {
                    s.replace(pos, search.length(), ss.str());
                }
            }
        }
        return QString(s);
    }

    int toInt() const {
        try {
            return std::stoi(*this);
        } catch (...) {
            return 0;
        }
    }

    QString toLower() const {
        std::string s = *this;
        std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return std::tolower(c); });
        return QString(s);
    }

    bool contains(const QString& other) const {
        return find(other) != std::string::npos;
    }

    QStringList split(char delim, int behavior = Qt::KeepEmptyParts) const;
};

class QStringList : public std::vector<QString> {
public:
    QStringList() : std::vector<QString>() {}
    QStringList(std::initializer_list<QString> l) : std::vector<QString>(l) {}

    bool isEmpty() const { return empty(); }

    QString join(const QString& sep) const {
        std::string res;
        for (size_t i = 0; i < size(); ++i) {
            res += (*this)[i];
            if (i + 1 < size()) res += sep;
        }
        return QString(res);
    }

    QString value(int i, const QString& fallback = "") const {
        if (i >= 0 && i < (int)size()) {
            return (*this)[i];
        }
        return fallback;
    }

    void append(const QString& val) { this->push_back(val); }
    void append(QString&& val) { this->push_back(std::move(val)); }
};

inline QStringList QString::split(char delim, int behavior) const {
    QStringList res;
    std::stringstream ss(*this);
    std::string item;
    while (std::getline(ss, item, delim)) {
        if (behavior == Qt::SkipEmptyParts && item.empty()) continue;
        res.push_back(QString(item));
    }
    return res;
}

typedef QString QByteArray;

template<typename T>
class QVector : public std::vector<T> {
public:
    using std::vector<T>::vector;
    void append(const T& val) { this->push_back(val); }
    void append(T&& val) { this->push_back(std::move(val)); }
    void reserve(size_t n) { std::vector<T>::reserve(n); }
    const T& at(size_t i) const { return (*this)[i]; }
};

class QObject {
public:
    QObject(QObject* parent = nullptr) {}
    virtual ~QObject() = default;
};

class QElapsedTimer {
private:
    std::chrono::steady_clock::time_point start_time_;
    bool valid_ = false;
public:
    void start() {
        start_time_ = std::chrono::steady_clock::now();
        valid_ = true;
    }
    void restart() {
        start();
    }
    void invalidate() {
        valid_ = false;
    }
    bool isValid() const {
        return valid_;
    }
    long long elapsed() const {
        if (!valid_) return 0;
        auto now = std::chrono::steady_clock::now();
        return std::chrono::duration_cast<std::chrono::milliseconds>(now - start_time_).count();
    }
};

namespace QIODevice {
    enum OpenMode { ReadOnly = 1, WriteOnly = 2, Text = 4 };
}

class QFile {
private:
    std::string path_;
    std::ifstream stream_;
public:
    QFile(const QString& path) : path_(path) {}
    bool open(int mode) {
        stream_.open(path_);
        return stream_.is_open();
    }
    bool atEnd() {
        return stream_.peek() == EOF;
    }
    QString readLine() {
        std::string line;
        std::getline(stream_, line);
        return QString(line);
    }
};

class QFileInfo {
private:
    std::string path_;
public:
    QFileInfo(const QString& path) : path_(path) {}
    bool exists() const {
        std::ifstream f(path_);
        return f.good();
    }
    QString fileName() const {
        size_t pos = path_.find_last_of("/\\");
        if (pos != std::string::npos) {
            return QString(path_.substr(pos + 1));
        }
        return QString(path_);
    }
    QString absolutePath() const {
        size_t pos = path_.find_last_of("/\\");
        if (pos != std::string::npos) {
            return QString(path_.substr(0, pos));
        }
        return QString(path_);
    }
};

class QThread {
public:
    static int idealThreadCount() {
        return 4;
    }
};

template<typename T>
inline void qRegisterMetaType(const char*) {}

inline int qMax(int a, int b) { return std::max(a, b); }

#endif
