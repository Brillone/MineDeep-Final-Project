from tkinter import Tk
from tkinter.filedialog import askopenfilename


def choose_file():
    root = Tk()

    root.withdraw()  # keep the root window from appearing

    root.wm_attributes('-topmost', 1)

    filename = askopenfilename()  # show an "Open" dialog box and return the path to the selected file

    root.quit()

    return filename

